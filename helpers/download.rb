=begin

This is a helper script that downloads all sources, packages and binaries that we need for this release
and stores it into the `src` and `blobs` directory where they are expected by the corresponding jobs.

=end

require 'digest/md5'
require 'tempfile'



{
  :jenkins_binary => {
    :url          => 'https://updates.jenkins-ci.org/download/war/1.642.4/jenkins.war',
    :checksum     => '6a99d9f7ac9924a4c0ff0b0744316cda',
    :target       => 'src/jenkins/jenkins-1.642.4.war'             # path needs to be relative within the release
  },
  :jre => {       # see http://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html for possible downloads
    :url          => 'http://download.oracle.com/otn-pub/java/jdk/8u77-b03/jre-8u77-linux-x64.tar.gz',
    :checksum     => '7e7d8d0918b4f81f6adde9fcb853a036',
    :header       => 'Cookie: oraclelicense=accept-securebackup-cookie', # Oracle prevents download without accepting license agreement, see http://stackoverflow.com/questions/10268583/downloading-java-jdk-on-linux-via-wget-is-shown-license-page-instead
    :target       => 'src/jre/jre-8u77-linux-x64.tar.gz'
  }
}.each do | binary_name, binary |
  tmp_file = Tempfile.new(binary_name.to_s).path
  target_file = File.join(Dir.pwd, binary[:target])
  puts "#### Downloading #{binary[:url]} into #{tmp_file}"

  if File.exists? target_file
    puts '## Skipping download, file exists!'
    next
  end

  wget_header = (binary.has_key?(:header) ? " --no-check-certificate --no-cookies  --header \"#{binary[:header]}\"" : '')
  `wget #{binary[:url]} -O #{tmp_file}#{wget_header}`

  # Calculate md5 checksum of downloaded file
  md5_download = Digest::MD5.hexdigest(File.read(tmp_file))

  # Check md5 of downloaded file with the expected md5 checksum
  if md5_download == binary[:checksum]
    puts "## Moved file to #{binary[:target]}"

    unless Dir.exists? (File.dirname target_file)
      # create target directory if it doesn't exist
      FileUtils.makedirs File.dirname(target_file)
    end
    # if checksum matches, move file into target directory
    FileUtils.move tmp_file, target_file
  else
    # if checksum does not match, show error message and delete temp file
    File.delete(tmp_file)
    puts "Checksum of #{binary_name} did not match! Expected: #{binary[:checksum]} -- Actual: #{md5_download}"
    exit 1
  end
end
