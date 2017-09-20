require 'spec_helper'

describe SqlFootprint::SqlAnonymizer do
  let(:anonymizer) { described_class.new }

  it 'formats INSERT statements' do
    sql = 'INSERT INTO "widgets" ("created_at", "name") VALUES ' \
    "('2016-05-1 6 19:16:04.981048', 12345) RETURNING \"id\""
    expect(anonymizer.anonymize(sql)).to eq 'INSERT INTO "widgets" ' \
    '("created_at", "name") VALUES (values-redacted) RETURNING "id"'
  end

  it 'formats IN clauses' do
    sql = Widget.where(name: [SecureRandom.uuid, SecureRandom.uuid]).to_sql
    expect(anonymizer.anonymize(sql)).to eq(
      'SELECT "widgets".* FROM "widgets" ' \
      'WHERE "widgets"."name" IN (values-redacted)'
    )
  end

  it 'formats LIKE clauses' do
    sql = Widget.where(['name LIKE ?', SecureRandom.uuid]).to_sql
    expect(anonymizer.anonymize(sql)).to eq(
      'SELECT "widgets".* FROM "widgets" ' \
      'WHERE (name LIKE \'value-redacted\')'
    )
  end

  it 'formats numbers' do
    sql = Widget.where(quantity: rand(100)).to_sql
    expect(anonymizer.anonymize(sql)).to eq(
      'SELECT "widgets".* FROM "widgets" ' \
      'WHERE "widgets"."quantity" = number-redacted'
    )

    ['>', '<', '!=', '<=', '>='].each do |operator|
      sql = Widget.where(["quantity #{operator} ?", rand(100)]).to_sql
      expect(anonymizer.anonymize(sql)).to eq(
        'SELECT "widgets".* FROM "widgets" ' \
        "WHERE (quantity #{operator} number-redacted)"
      )
    end
  end

  it 'formats string literals' do
    sql = Widget.where(name: SecureRandom.uuid).to_sql
    expect(anonymizer.anonymize(sql)).to eq(
      'SELECT "widgets".* FROM "widgets" ' \
      'WHERE "widgets"."name" = \'value-redacted\''
    )
  end

  it 'formats string literals inside of LOWER' do
    sql = Widget.where("name = LOWER('whatever')").to_sql
    expect(anonymizer.anonymize(sql)).to eq(
      'SELECT "widgets".* FROM "widgets" ' \
      'WHERE (name = LOWER(\'value-redacted\'))'
    )
  end

  it 'formats unicode string literals for MSSQL' do
    sql = Widget.where("name = N''whatever''").to_sql
    expect(anonymizer.anonymize(sql)).to eq(
      'SELECT "widgets".* FROM "widgets" ' \
      'WHERE (name = N\'\'value-redacted\'\')'
    )
  end

  shared_examples 'correctly anonymizes value expression' do |name, statement:, expected:, invert: false|
    it "does#{invert ? ' not' : ''} anonymize #{name}" do
      expect(anonymizer.anonymize(statement)).to eq expected
    end
  end

  context 'value expressions tests' do
    {
      'aliased functions' => {
        statement: 'SELECT pg_advisory_unlock(1005314654,0) AS t56ebed72b0fec87fa34cc27ebfb96d5b',
        expected: 'SELECT pg_advisory_unlock(args-redacted) AS alias-redacted'
      },
      'aliased constants' => {
        statement: 'SELECT 51235 AS constant',
        expected: 'SELECT value-redacted AS alias-redacted'
      },
      'non-aliased functions' => {
        statement: 'SELECT pg_fn(arg1, arg2)',
        expected: 'SELECT pg_fn(args-redacted)'
      },
      'non-aliased constants' => {
        statement: "SELECT 'Some Constant'",
        expected: 'SELECT value-redacted'
      },
      'nested value expressions' => {
        statement: "SELECT id, (SELECT 'constant') AS alias FROM records",
        expected: "SELECT id, (SELECT 'value-redacted') AS alias FROM records"
      }
    }.each_pair do |name, expectation|
      include_examples 'correctly anonymizes value expression', name, expectation
    end

    context 'non-value expression queries' do
      {
        'normal aggregate query' => {
          statement: 'SELECT json_agg(t.name, t.value) AS alias FROM table t',
          expected: 'SELECT json_agg(t.name, t.value) AS alias FROM table t'
        },
        'plain query with alias' => {
          statement: 'SELECT id AS record_id FROM records',
          expected: 'SELECT id AS record_id FROM records'
        },
        'update statement' => {
          statement: %q{UPDATE "payer_rules" SET "starts_at" = NULL, "ends_at" = NULL, "created_at" = 'date string' WHERE "payer_rules"."id" = $1},
          expected: %q{UPDATE "payer_rules" SET "starts_at" = NULL, "ends_at" = NULL, "created_at" = 'value-redacted' WHERE "payer_rules"."id" = $1}
        },
        'long join' => {
          statement: <<-SQL,
            SELECT records.id as last_record_id, ops_records.*, "ops_records"."id" AS t0_r0, "ops_records"."alert_id" AS t0_r1, "ops_records"."ops_record_status_id" AS t0_r2, "ops_records"."vaccine_copay_id" AS t0_r3, "ops_records"."key" AS t0_r4, "ops_records"."answered_at" AS t0_r5, "ops_records"."completed_at" AS t0_r6, "ops_records"."viewed_at" AS t0_r7, "ops_records"."due_date" AS t0_r8, "ops_records"."created_at" AS t0_r9, "ops_records"."updated_at" AS t0_r10, "ops_records"."send_on" AS t0_r11, "ops_records"."sent_at" AS t0_r12, "ops_records"."uuid" AS t0_r13, "ops_records"."title" AS t0_r14, "alerts"."id" AS t1_r0, "alerts"."patient_id" AS t1_r1, "alerts"."rx_number" AS t1_r2, "alerts"."pharmacy_npi" AS t1_r3, "alerts"."provider_npi" AS t1_r4, "alerts"."provider_fax_number" AS t1_r5, "alerts"."alerted_at" AS t1_r6, "alerts"."expires_at" AS t1_r7, "alerts"."alert_status_id" AS t1_r8, "alerts"."days_supply" AS t1_r9, "alerts"."fill_number" AS t1_r10, "alerts"."quantity_dispensed" AS t1_r11, "alerts"."original_fill_date" AS t1_r12, "alerts"."patient_hash_id" AS t1_r13, "alerts"."replaced_at" AS t1_r14, "alerts"."sig" AS t1_r15, "alerts"."created_at" AS t1_r16, "alerts"."updated_at" AS t1_r17, "alerts"."drug_ndc" AS t1_r18, "alerts"."accounts_survey_id" AS t1_r19, "alerts"."alert_billable_status_id" AS t1_r20, "alerts"."fax_sent_at" AS t1_r21, "alerts"."billable_at" AS t1_r22, "alerts"."is_fresh" AS t1_r23, "alerts"."message_id" AS t1_r24, "alerts"."alert_type_id" AS t1_r25, "messages"."id" AS t2_r0, "messages"."api_key" AS t2_r1, "messages"."rejection_code" AS t2_r2, "messages"."rejection_message" AS t2_r3, "messages"."bin" AS t2_r4, "messages"."pcn" AS t2_r5, "messages"."group_id" AS t2_r6, "messages"."cardhold_id" AS t2_r7, "messages"."person_code" AS t2_r8, "messages"."prescription_reference_number" AS t2_r9, "messages"."prescription_reference_number_qualifier" AS t2_r10, "messages"."product_service_id" AS t2_r11, "messages"."product_service_id_qualifier" AS t2_r12, "messages"."service_provider_id" AS t2_r13, "messages"."service_provider_id_qualifier" AS t2_r14, "messages"."prescriber_id" AS t2_r15, "messages"."prescriber_id_qualifier" AS t2_r16, "messages"."message_type" AS t2_r17, "messages"."message" AS t2_r18, "messages"."button_label" AS t2_r19, "messages"."uuid" AS t2_r20, "messages"."approval_code" AS t2_r21, "messages"."days_supply" AS t2_r22, "messages"."fill_number" AS t2_r23, "messages"."quantity_dispensed" AS t2_r24, "messages"."transaction_response_status" AS t2_r25, "messages"."patient_age" AS t2_r26, "messages"."patient_hash_id" AS t2_r27, "messages"."prescriber_fax" AS t2_r28, "messages"."prescriber_phone" AS t2_r29, "messages"."pharmacy_service_type" AS t2_r30, "messages"."sig" AS t2_r31, "messages"."created_at" AS t2_r32, "messages"."number_of_refills_authorized" AS t2_r33, "messages"."number_of_refills_remaining" AS t2_r34, "messages"."prescription_expires_at" AS t2_r35, "messages"."system_vendor_patient_id" AS t2_r36, "accounts_surveys"."id" AS t3_r0, "accounts_surveys"."account_id" AS t3_r1, "accounts_surveys"."survey_id" AS t3_r2, "accounts_surveys"."enabled" AS t3_r3, "accounts_surveys"."created_at" AS t3_r4, "accounts_surveys"."updated_at" AS t3_r5, "surveys"."id" AS t4_r0, "surveys"."program_id" AS t4_r1, "surveys"."version_id" AS t4_r2, "surveys"."created_at" AS t4_r3, "surveys"."updated_at" AS t4_r4, "programs"."id" AS t5_r0, "programs"."name" AS t5_r1, "programs"."active" AS t5_r2, "programs"."created_at" AS t5_r3, "programs"."updated_at" AS t5_r4, "programs"."deleted_at" AS t5_r5, "programs"."program_identifier" AS t5_r6, "programs"."default_survey_id" AS t5_r7, "programs"."is_sponsored" AS t5_r8, "patients"."id" AS t6_r0, "patients"."created_at" AS t6_r1, "patients"."updated_at" AS t6_r2, "patients"."do_not_contact" AS t6_r3, "patients"."uuid" AS t6_r4, "patients"."api_client_id" AS t6_r5, "patients"."api_client_patient_id" AS t6_r6, "ops_record_statuses"."id" AS t7_r0, "ops_record_statuses"."description" AS t7_r1 FROM "ops_records" INNER JOIN "alerts" ON "alerts"."id" = "ops_records"."alert_id" INNER JOIN "accounts_surveys" ON "accounts_surveys"."id" = "alerts"."accounts_survey_id" INNER JOIN "accounts" ON "accounts"."id" = "accounts_surveys"."account_id" AND "accounts"."deleted_at" IS NULL INNER JOIN "surveys" ON "surveys"."id" = "accounts_surveys"."survey_id" INNER JOIN "programs" ON "programs"."id" = "surveys"."program_id" AND "programs"."deleted_at" IS NULL INNER JOIN "messages" ON "messages"."id" = "alerts"."message_id" INNER JOIN "patients" ON "patients"."id" = "alerts"."patient_id" INNER JOIN "ops_record_statuses" ON "ops_record_statuses"."id" = "ops_records"."ops_record_status_id" JOIN pharmacies p ON p.npi = alerts.pharmacy_npi JOIN pharmacy_config pc ON pc.pharmacy_id = p.id JOIN config_names cn ON cn.id = pc.config_name_id LEFT JOIN answers
               ON ops_records.alert_id = answers.alert_id
                 AND answers.id = (
                    SELECT MAX(a.id)
                    FROM answers a
                    JOIN questions q ON q.id = a.question_id
                      AND q.question_identifier = 'some more text'
                    WHERE alert_id = ops_records.alert_id
                 )
             LEFT JOIN records
               ON records.id = answers.choice_id
                 AND records.deleted_at IS NULL WHERE "accounts"."system_vendor_api_key" = 'some text')) AND "alerts"."pharmacy_npi" = $1
          SQL
          expected: <<-SQL
            SELECT records.id as last_record_id, ops_records.*, "ops_records"."id" AS t0_r0, "ops_records"."alert_id" AS t0_r1, "ops_records"."ops_record_status_id" AS t0_r2, "ops_records"."vaccine_copay_id" AS t0_r3, "ops_records"."key" AS t0_r4, "ops_records"."answered_at" AS t0_r5, "ops_records"."completed_at" AS t0_r6, "ops_records"."viewed_at" AS t0_r7, "ops_records"."due_date" AS t0_r8, "ops_records"."created_at" AS t0_r9, "ops_records"."updated_at" AS t0_r10, "ops_records"."send_on" AS t0_r11, "ops_records"."sent_at" AS t0_r12, "ops_records"."uuid" AS t0_r13, "ops_records"."title" AS t0_r14, "alerts"."id" AS t1_r0, "alerts"."patient_id" AS t1_r1, "alerts"."rx_number" AS t1_r2, "alerts"."pharmacy_npi" AS t1_r3, "alerts"."provider_npi" AS t1_r4, "alerts"."provider_fax_number" AS t1_r5, "alerts"."alerted_at" AS t1_r6, "alerts"."expires_at" AS t1_r7, "alerts"."alert_status_id" AS t1_r8, "alerts"."days_supply" AS t1_r9, "alerts"."fill_number" AS t1_r10, "alerts"."quantity_dispensed" AS t1_r11, "alerts"."original_fill_date" AS t1_r12, "alerts"."patient_hash_id" AS t1_r13, "alerts"."replaced_at" AS t1_r14, "alerts"."sig" AS t1_r15, "alerts"."created_at" AS t1_r16, "alerts"."updated_at" AS t1_r17, "alerts"."drug_ndc" AS t1_r18, "alerts"."accounts_survey_id" AS t1_r19, "alerts"."alert_billable_status_id" AS t1_r20, "alerts"."fax_sent_at" AS t1_r21, "alerts"."billable_at" AS t1_r22, "alerts"."is_fresh" AS t1_r23, "alerts"."message_id" AS t1_r24, "alerts"."alert_type_id" AS t1_r25, "messages"."id" AS t2_r0, "messages"."api_key" AS t2_r1, "messages"."rejection_code" AS t2_r2, "messages"."rejection_message" AS t2_r3, "messages"."bin" AS t2_r4, "messages"."pcn" AS t2_r5, "messages"."group_id" AS t2_r6, "messages"."cardhold_id" AS t2_r7, "messages"."person_code" AS t2_r8, "messages"."prescription_reference_number" AS t2_r9, "messages"."prescription_reference_number_qualifier" AS t2_r10, "messages"."product_service_id" AS t2_r11, "messages"."product_service_id_qualifier" AS t2_r12, "messages"."service_provider_id" AS t2_r13, "messages"."service_provider_id_qualifier" AS t2_r14, "messages"."prescriber_id" AS t2_r15, "messages"."prescriber_id_qualifier" AS t2_r16, "messages"."message_type" AS t2_r17, "messages"."message" AS t2_r18, "messages"."button_label" AS t2_r19, "messages"."uuid" AS t2_r20, "messages"."approval_code" AS t2_r21, "messages"."days_supply" AS t2_r22, "messages"."fill_number" AS t2_r23, "messages"."quantity_dispensed" AS t2_r24, "messages"."transaction_response_status" AS t2_r25, "messages"."patient_age" AS t2_r26, "messages"."patient_hash_id" AS t2_r27, "messages"."prescriber_fax" AS t2_r28, "messages"."prescriber_phone" AS t2_r29, "messages"."pharmacy_service_type" AS t2_r30, "messages"."sig" AS t2_r31, "messages"."created_at" AS t2_r32, "messages"."number_of_refills_authorized" AS t2_r33, "messages"."number_of_refills_remaining" AS t2_r34, "messages"."prescription_expires_at" AS t2_r35, "messages"."system_vendor_patient_id" AS t2_r36, "accounts_surveys"."id" AS t3_r0, "accounts_surveys"."account_id" AS t3_r1, "accounts_surveys"."survey_id" AS t3_r2, "accounts_surveys"."enabled" AS t3_r3, "accounts_surveys"."created_at" AS t3_r4, "accounts_surveys"."updated_at" AS t3_r5, "surveys"."id" AS t4_r0, "surveys"."program_id" AS t4_r1, "surveys"."version_id" AS t4_r2, "surveys"."created_at" AS t4_r3, "surveys"."updated_at" AS t4_r4, "programs"."id" AS t5_r0, "programs"."name" AS t5_r1, "programs"."active" AS t5_r2, "programs"."created_at" AS t5_r3, "programs"."updated_at" AS t5_r4, "programs"."deleted_at" AS t5_r5, "programs"."program_identifier" AS t5_r6, "programs"."default_survey_id" AS t5_r7, "programs"."is_sponsored" AS t5_r8, "patients"."id" AS t6_r0, "patients"."created_at" AS t6_r1, "patients"."updated_at" AS t6_r2, "patients"."do_not_contact" AS t6_r3, "patients"."uuid" AS t6_r4, "patients"."api_client_id" AS t6_r5, "patients"."api_client_patient_id" AS t6_r6, "ops_record_statuses"."id" AS t7_r0, "ops_record_statuses"."description" AS t7_r1 FROM "ops_records" INNER JOIN "alerts" ON "alerts"."id" = "ops_records"."alert_id" INNER JOIN "accounts_surveys" ON "accounts_surveys"."id" = "alerts"."accounts_survey_id" INNER JOIN "accounts" ON "accounts"."id" = "accounts_surveys"."account_id" AND "accounts"."deleted_at" IS NULL INNER JOIN "surveys" ON "surveys"."id" = "accounts_surveys"."survey_id" INNER JOIN "programs" ON "programs"."id" = "surveys"."program_id" AND "programs"."deleted_at" IS NULL INNER JOIN "messages" ON "messages"."id" = "alerts"."message_id" INNER JOIN "patients" ON "patients"."id" = "alerts"."patient_id" INNER JOIN "ops_record_statuses" ON "ops_record_statuses"."id" = "ops_records"."ops_record_status_id" JOIN pharmacies p ON p.npi = alerts.pharmacy_npi JOIN pharmacy_config pc ON pc.pharmacy_id = p.id JOIN config_names cn ON cn.id = pc.config_name_id LEFT JOIN answers
               ON ops_records.alert_id = answers.alert_id
                 AND answers.id = (
                    SELECT MAX(a.id)
                    FROM answers a
                    JOIN questions q ON q.id = a.question_id
                      AND q.question_identifier = 'value-redacted'
                    WHERE alert_id = ops_records.alert_id
                 )
             LEFT JOIN records
               ON records.id = answers.choice_id
                 AND records.deleted_at IS NULL WHERE "accounts"."system_vendor_api_key" = 'value-redacted')) AND "alerts"."pharmacy_npi" = $1
          SQL
        }
      }.each_pair do |name, expectation|
        include_examples 'correctly anonymizes value expression', name, expectation.merge(invert: true)
      end
    end
  end
end
