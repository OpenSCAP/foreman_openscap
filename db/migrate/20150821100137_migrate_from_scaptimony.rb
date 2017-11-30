class MigrateFromScaptimony < ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::ConnectionAdapters::SchemaStatements.module_eval do
      # rename_tables renames the indexes, and their new names overflow, we cancel out the renaming of the indexes
      alias_method :old_rename_table_indexes, :rename_table_indexes
      def rename_table_indexes(a, b)
      end
    end

    execute 'DROP VIEW IF EXISTS scaptimony_arf_report_breakdowns'
    execute 'DROP VIEW IF EXISTS foreman_openscap_arf_report_breakdowns'

    ActiveRecord::Base.connection.tables.grep(/^scaptimony/).each do |table|
      rename_table table, table.sub(/^scaptimony/, "foreman_openscap")
    end

    execute <<-SQL
      CREATE VIEW foreman_openscap_arf_report_breakdowns AS
        SELECT
          arf.id as arf_report_id,
          COUNT(CASE WHEN result.name IN ('pass','fixed') THEN 1 ELSE null END) as passed,
          COUNT(CASE result.name WHEN 'fail' THEN 1 ELSE null END) as failed,
          COUNT(CASE WHEN result.name NOT IN ('pass', 'fixed', 'fail', 'notselected', 'notapplicable') THEN 1 ELSE null END) as othered
        FROM
          foreman_openscap_arf_reports arf
        LEFT OUTER JOIN
          foreman_openscap_xccdf_rule_results rule
          ON arf.id = rule.arf_report_id
        LEFT OUTER JOIN foreman_openscap_xccdf_results result
          ON rule.xccdf_result_id = result.id
        GROUP BY arf.id;
          SQL

    taxonomies = TaxableTaxonomy.where(:taxable_type => ["Scaptimony::ArfReport", "Scaptimony::Policy", "Scaptimony::ScapContent"])
    taxonomies.each { |t| t.taxable_type = t.taxable_type.sub(/^Scaptimony/, "ForemanOpenscap") }.map(&:save!)
  ensure
    ActiveRecord::ConnectionAdapters::SchemaStatements.module_eval do
      alias_method :rename_table_indexes, :old_rename_table_indexes
    end
  end

  def down
    execute 'DROP VIEW IF EXISTS scaptimony_arf_report_breakdowns'
    execute 'DROP VIEW IF EXISTS foreman_openscap_arf_report_breakdowns'

    ActiveRecord::Base.connection.tables.grep(/^foreman_openscap/).each do |table|
      rename_table table, table.sub(/^foreman_openscap/, "scaptimony")
    end

    execute <<-SQL
      CREATE VIEW scaptimony_arf_report_breakdowns AS
        SELECT
          arf.id as arf_report_id,
          COUNT(CASE WHEN result.name IN ('pass','fixed') THEN 1 ELSE null END) as passed,
          COUNT(CASE result.name WHEN 'fail' THEN 1 ELSE null END) as failed,
          COUNT(CASE WHEN result.name NOT IN ('pass', 'fixed', 'fail', 'notselected', 'notapplicable') THEN 1 ELSE null END) as othered
        FROM
          scaptimony_arf_reports arf
        LEFT OUTER JOIN
          scaptimony_xccdf_rule_results rule
          ON arf.id = rule.arf_report_id
        LEFT OUTER JOIN scaptimony_xccdf_results result
          ON rule.xccdf_result_id = result.id
        GROUP BY arf.id;
          SQL

    taxonomies = TaxableTaxonomy.where(:taxable_type => ["ForemanOpenscap::ArfReport", "ForemanOpenscap::Policy", "ForemanOpenscap::ScapContent"])
    taxonomies.each { |t| t.taxable_type = t.taxable_type.sub(/^ForemanOpenscap/, "Scaptimony") }.map(&:save!)
  end
end
