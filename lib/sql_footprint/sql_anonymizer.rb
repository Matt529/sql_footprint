module SqlFootprint
  class SqlAnonymizer
    GSUBS = {
      /\sIN\s\(.*\)/ => ' IN (values-redacted)'.freeze, # IN clauses
      /([\s\(])'.*'/ => "\\1'value-redacted'".freeze, # literal strings
      /N''.*''/ => "N''value-redacted''".freeze, # literal MSSQL strings
      /\s+(!=|=|<|>|<=|>=)\s+[0-9]+/ => ' \1 number-redacted', # numbers
      /\s+VALUES\s+\(.+\)/ => ' VALUES (values-redacted)', # VALUES
      /(?!.+\n*.*FROM)SELECT (?![\w_]+\()(.+) AS (.+)/ => 'SELECT value-redacted AS alias-redacted', # Constant Value Expressions w/ Alias
      /(?!.+\n*.*FROM)SELECT ([\w_]+)\((.+)\) AS (.+)/ => 'SELECT \1(args-redacted) AS alias-redacted', # Function Value Expressions w/ Alias
      /(?!.+\n*.*FROM)(?!.+AS)SELECT (?![\w_]+\()(.+)/ => 'SELECT value-redacted', # Constant Value Expression
      /(?!.+\n*.*FROM)(?!.+AS)SELECT ([\w_]+)\((.+)\)/ => 'SELECT \1(args-redacted)', # Function Value Expression
    }.freeze

    def anonymize sql
      GSUBS.reduce(sql) do |s, (regex, replacement)|
        s.gsub regex, replacement
      end
    end
  end
end
