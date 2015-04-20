# Tasks
namespace :foreman_openscap do
  require 'foreman_openscap/bulk_upload'
  namespace :bulk_upload do
    desc 'Bulk upload SCAP content from directory'
    task :directory, [:directory] => [:environment] do |task, args|
      abort("# No such directory, please check the path you have provided. #") unless args[:directory].blank? || Dir.exist?(args[:directory])
      ForemanOpenscap::BulkUpload.new.upload_from_directory(args[:directory])
    end

    task :files, [:files] => [:environment] do |task, args|
      files_array = args[:files].split(' ')
      files_array.each do |file|
        abort("# #{file} is a directory, expecting file. Try using 'rake foreman_openscap:bulk_upload:directory' with this directory. #") if File.directory?(file)
      end
      ForemanOpenscap::BulkUpload.new.upload_from_files(files_array)
    end
  end
end

# Tests
namespace :test do
  desc "Test ForemanOpenscap"
  Rake::TestTask.new(:foreman_openscap) do |t|
    test_dir = File.join(File.dirname(__FILE__), '../..', 'test')
    t.libs << ["test",test_dir]
    t.pattern = "#{test_dir}/**/*_test.rb"
    t.verbose = true
  end
end

Rake::Task[:test].enhance do
  Rake::Task['test:foreman_openscap'].invoke
end

load 'tasks/jenkins.rake'
if Rake::Task.task_defined?(:'jenkins:setup')
  Rake::Task["jenkins:unit"].enhance do
    Rake::Task['test:foreman_openscap'].invoke
  end
end
