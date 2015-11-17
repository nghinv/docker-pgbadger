#!/usr/bin/ruby

require 'aws-sdk'

ENV['DB_INSTANCE_IDENTIFIER'] or raise 'DB_INSTANCE_IDENTIFIER is required'
ENV['BUCKET'] or raise 'BUCKET is required'

rds = Aws::RDS::Client.new
files = rds.describe_db_log_files(db_instance_identifier: ENV['DB_INSTANCE_IDENTIFIER'])
files = files.to_h[:describe_db_log_files]

log_file_count = ENV['LOG_FILE_COUNT'] ? ENV['LOG_FILE_COUNT'].to_i : 5

files.last(log_file_count).each do |file|
  puts file[:log_file_name]
  system "rds-download-db-logfile --db-instance-identifier #{ENV['DB_INSTANCE_IDENTIFIER']} " +
             "-I #{ENV['AWS_ACCESS_KEY_ID']} -S #{ENV['AWS_SECRET_ACCESS_KEY']} " +
             "--log-file-name #{file[:log_file_name]} | pv -s #{file[:size]} >#{File.basename(file[:log_file_name])}"
end

system("pgbadger -p '%t:%r:%u@%d:[%p]:' *") or raise 'pgbadger failed'

s3 = Aws::S3::Resource.new
obj = s3.bucket(ENV['BUCKET']).object("pgbadger-#{Date.today}.html")
obj.upload_file 'out.html', {acl: 'public-read'}