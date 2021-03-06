=begin
--------------------------------------------------------------------------------

Create a distillation of this site that can be used to create additional triples.

1) instance_to_worldcat.txt will be used to link instances across sites.
2) work_to_workID.txt will be used to link works across sites, and also to
   generate WorkID triples.

--------------------------------------------------------------------------------
=end

require_relative 'distiller_core'

module Ld4lBrowserData
  module AdditionalTriples
    class SiteDistiller
      include Utilities::MainClassHelper
      include DistillerCore
      def initialize
        @usage_text = [
          'Usage is ld4l_distill_site \\',
          'source=<source_directory> \\',
          'target=<target_directory>[~REPLACE] \\',
          'concordance=<concordance_file> \\',
          'report=<report_file>[~REPLACE] \\'
        ]
      end

      def process_arguments()
        parse_arguments(:source, :target, :concordance, :report)

        @source_dir = validate_input_directory(:source, "source_directory")
        @target_dir = validate_output_directory(:target, "target_directory")
        @concordance = validate_input_file(:concordance, "concordance file")
        @report = Report.new('ld4l_distill_site', validate_output_file(:report, "report file"))

        @source_files = find_source_file_paths(/\.nt$/)
        @work_to_instance = in_target_dir('work_to_instance.txt')
        @instances = in_target_dir('instances.txt')
        @instance_to_worldcat = in_target_dir('instance_to_worldcat.txt')
        @instance_to_identifiers = in_target_dir('instance_to_identifier.txt')
        @object_to_identifiers = in_target_dir('object_to_identifier.txt')
        @oclc_identifiers = in_target_dir('oclc_identifiers.txt')
        @identifier_to_value = in_target_dir('identifier_to_value.txt')
        @instance_to_oclc = in_target_dir('instance_to_oclc.txt')
        @the_hard_way = in_target_dir('instance_to_worldcat_the_hard_way.txt')
        @all_instance_to_worldcat = in_target_dir('instance_to_worldcat_all.txt')
        @work_instance_worldcat = in_target_dir('work_to_instance_to_worldcat.txt')
        @work_to_work_id = in_target_dir('work_to_workID.txt')

        @report.log_header
      end

      def create_work_to_instance()
        @report.start_method("create_work_to_instance")
        pattern = /http:\/\/bib\.ld4l\.org\/ontology\/isInstanceOf/
        count = 0
        File.open(@work_to_instance, 'w') do |out|
          @source_files.each do |path|
            File.foreach(path) do |line|
              if pattern =~ line
                fields = line.split
                out.puts(strip_angles(fields[2]) + ' ' + strip_angles(fields[0]))
                count += 1
              end
            end
          end
        end
        @report.end_method_with_count("create_work_to_instance", count)
      end

      def create_instance_to_worldcat()
        @report.start_method("create_instance_to_worldcat")
        pattern = /http:\/\/www\.w3\.org\/2002\/07\/owl#sameAs.*http:\/\/www\.worldcat\.org\/oclc/
        count = 0
        File.open(@instance_to_worldcat, 'w') do |out|
          @source_files.each do |path|
            File.foreach(path) do |line|
              if pattern =~ line
                fields = line.split
                out.puts(strip_angles(fields[0]) + " " + get_localname(fields[2]))
                count += 1
              end
            end
          end
        end
        @report.end_method_with_count("create_instance_to_worldcat", count)
      end

      def create_identifier_to_value()
        @report.start_method("create_identifier_to_value")
        pattern = /22-rdf-syntax-ns#value/
        count = 0
        File.open(@identifier_to_value, 'w') do |out|
          @source_files.each do |path|
            File.foreach(path) do |line|
              if pattern =~ line
                fields = line.split
                out.puts(strip_angles(fields[0]) + " " + strip_quotes(fields[2]))
                count += 1
              end
            end
          end
        end
        @report.end_method_with_count("create_identifier_to_value", count)
      end

      def create_additional_worldcat_ids
        filter(/http:\/\/bib\.ld4l\.org\/ontology\/Instance/, @instances)
        filter(/identifiedBy/, @object_to_identifiers)
        filter(/OclcIdentifier/, @oclc_identifiers)

        join(@object_to_identifiers, 1, @instances, 1, @instance_to_identifiers, [[1, 1], [1, 2], [1, 3]])
        join(@instance_to_identifiers, 3, @oclc_identifiers, 1, @instance_to_oclc, [[1, 1], [1, 3]])
        join(@instance_to_oclc, 2, @identifier_to_value, 1, @the_hard_way, [[1, 1], [2, 2]])

        concat(@instance_to_worldcat, @the_hard_way, @all_instance_to_worldcat)
      end

      def create_work_to_work_ids()
        join(@work_to_instance, 2, @all_instance_to_worldcat, 1, @work_instance_worldcat, [[1, 1], [1, 2], [2, 2]])
        join(@work_instance_worldcat, 3, @concordance, 1, @work_to_work_id, [[1, 1], [2, 2]])
      end

      def run
        begin
          process_arguments
          create_work_to_instance
          create_instance_to_worldcat
          create_identifier_to_value
          create_additional_worldcat_ids
          create_work_to_work_ids
        rescue UserInputError, IllegalStateError
          puts
          puts "ERROR: #{$!}"
          puts
          exit 1
        ensure
          @report.close if @report
        end
      end
    end
  end
end
