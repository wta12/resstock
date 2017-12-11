require 'bundler'
require 'rake'
require 'rake/testtask'
Bundler.setup

desc 'Copy measures/osms from OpenStudio-BEopt repo'
task :copy_beopt_files do
  require 'fileutils'
  require 'openstudio'
  require 'net/http'
  require 'openssl'

  STDOUT.puts "Enter branch of repo (<ENTER> for master):"
  branch = STDIN.gets.strip
  if branch.empty?
    branch = "master"
  end
  
  if File.exists? File.join(File.dirname(__FILE__), "#{branch}.zip")
    FileUtils.rm(File.join(File.dirname(__FILE__), "#{branch}.zip"))
  end

  url = URI.parse("https://codeload.github.com/NREL/OpenStudio-BEopt/zip/#{branch}")
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  params = { 'User-Agent' => 'curl/7.43.0', 'Accept-Encoding' => 'identity' }
  request = Net::HTTP::Get.new(url.path, params)
  request.content_type = 'application/zip, application/octet-stream'

  http.request request do |response|
    total = response.header["Content-Length"].to_i
    if total == 0
      fail "Did not successfully download zip file."
    end
    size = 0
    progress = 0
    open "#{branch}.zip", 'wb' do |io|
      response.read_body do |chunk|
        io.write chunk
        size += chunk.size
        new_progress = (size * 100) / total
        unless new_progress == progress
          puts "Downloading %s (%3d%%) " % [url.path, new_progress]
        end
        progress = new_progress
      end
    end
  end

  puts "Extracting latest residential measures..."
  unzip_file = OpenStudio::UnzipFile.new(File.join(File.dirname(__FILE__), "#{branch}.zip"))
  unzip_file.extractAllFiles(OpenStudio::toPath(File.join(File.dirname(__FILE__), branch)))

  beopt_measures_dir = File.join(File.dirname(__FILE__), branch, "OpenStudio-BEopt-#{branch}", "measures")
  buildstock_resource_measures_dir = File.join(File.dirname(__FILE__), "resources", "measures")
  
  # Copy seed osm and other needed resource files
  project_dir_names = get_all_project_dir_names()
  extra_files = [
                 File.join("seeds", "EmptySeedModel.osm"),
                 File.join("workflows", "measure-info.json"),
                 File.join("resources", "meta_measure.rb") # Needed by buildstock.rb
                ]
  extra_files.each do |extra_file|
      puts "Copying #{extra_file}..."
      beopt_file = File.join(File.dirname(__FILE__), branch, "OpenStudio-BEopt-#{branch}", extra_file)
      if extra_file.start_with?("seeds") # Distribute to all projects
        project_dir_names.each do |project_dir_name|
          buildstock_file = File.join(File.dirname(__FILE__), project_dir_name, extra_file)
          if File.exists?(buildstock_file)
            FileUtils.rm(buildstock_file)
          end
          FileUtils.cp(beopt_file, buildstock_file)
        end
      else # Copy to resources dir
        buildstock_file = File.join(File.dirname(__FILE__), "resources", File.basename(extra_file))
        if File.exists?(buildstock_file)
          FileUtils.rm(buildstock_file)
        end
        FileUtils.cp(beopt_file, buildstock_file)
      end
  end
  
  # Clean out resources/measures/ dir
  puts "Deleting #{buildstock_resource_measures_dir}..."
  while Dir.exist?(buildstock_resource_measures_dir)
    FileUtils.rm_rf("#{buildstock_resource_measures_dir}/.", secure: true)
    sleep 1
  end
  FileUtils.makedirs(buildstock_resource_measures_dir)
  
  # Copy residential measures to resources/measures/
  Dir.foreach(beopt_measures_dir) do |beopt_measure|
    next if !beopt_measure.include? 'Residential'
    beopt_measure_dir = File.join(beopt_measures_dir, beopt_measure)
    next if not Dir.exist?(beopt_measure_dir)
    puts "Copying #{beopt_measure} measure..."
    FileUtils.cp_r(beopt_measure_dir, buildstock_resource_measures_dir)
    ["coverage","tests"].each do |subdir|
      buildstock_resource_measures_subdir = File.join(buildstock_resource_measures_dir, beopt_measure, subdir)
      if Dir.exist?(buildstock_resource_measures_subdir)
        FileUtils.rm_rf("#{buildstock_resource_measures_subdir}/.", secure: true)
      end
    end
    if beopt_measure == "ResidentialPhotovoltaics"
      ["resources"].each do |subdir|
        beopt_measure_subdir = File.join(buildstock_resource_measures_dir, beopt_measure, subdir)
        remove_items_from_zip_file(beopt_measure_subdir, "sam-sdk-2017-1-17-r1.zip", ["osx64", "win32", "win64"])
      end
    end    
  end
  
  # Copy other measures to measure/ dir
  other_measures = ["TimeseriesCSVExport", "UtilityBillCalculations"]
  buildstock_measures_dir = buildstock_resource_measures_dir = File.join(File.dirname(__FILE__), "measures")
  other_measures.each do |other_measure|
    puts "Copying #{other_measure} measure..."
    FileUtils.cp_r(File.join(beopt_measures_dir, other_measure), buildstock_measures_dir)
    ["coverage","tests"].each do |subdir|
      buildstock_measure_subdir = File.join(buildstock_measures_dir, other_measure, subdir)
      if Dir.exist?(buildstock_measure_subdir)
        FileUtils.rm_rf("#{buildstock_measure_subdir}/.", secure: true)
      end
    end
    if other_measure == "UtilityBillCalculations"
      ["resources"].each do |subdir|
        buildstock_measure_subdir = File.join(buildstock_measures_dir, other_measure, subdir)
        remove_items_from_zip_file(buildstock_measure_subdir, "sam-sdk-2017-1-17-r1.zip", ["osx64", "win32", "win64"])
        puts "Extracting tariffs..."
        move_and_extract_zip_file(buildstock_measure_subdir, "tariffs.zip", "./resources")
      end
    end
  end

  puts "Cleaning up..."
  FileUtils.rm_rf(File.join(File.dirname(__FILE__), branch))

end

def remove_items_from_zip_file(dir, zip_file_name, items)
  unzip_file = OpenStudio::UnzipFile.new(File.join(dir, zip_file_name))
  unzip_file.extractAllFiles(OpenStudio::toPath(File.join(dir, zip_file_name.gsub(".zip", ""))))
  items.each do |item|
    FileUtils.rm_rf(File.join(dir, zip_file_name.gsub(".zip", ""), item))
  end
  zip_path = OpenStudio::toPath(File.join(dir, zip_file_name))
  zip_file = OpenStudio::ZipFile.new(zip_path, false)
  zip_file.addDirectory(File.join(dir, zip_file_name.gsub(".zip", "")), OpenStudio::toPath("/"))
  FileUtils.rm_rf(File.join(dir, zip_file_name.gsub(".zip", "")))
end

def move_and_extract_zip_file(dir, zip_file_name, target)
  unzip_file = OpenStudio::UnzipFile.new(File.join(dir, zip_file_name))
  unzip_file.extractAllFiles(OpenStudio::toPath(File.join(dir, zip_file_name.gsub(".zip", ""))))
  FileUtils.rm_rf(File.join(target, zip_file_name.gsub(".zip", "")))
  FileUtils.mv(File.join(dir, zip_file_name.gsub(".zip", "")), target)
end

namespace :test do

  desc 'Run unit tests for all projects/measures'
  Rake::TestTask.new('all') do |t|
    t.libs << 'test'
    t.test_files = Dir['project_*/tests/*.rb'] + Dir['measures/*/tests/*.rb']
    t.warning = false
    t.verbose = true
  end
  
  desc 'regenerate SimulationOutputReport test osm files from osw files'
  task :regenerate_osms do

    num_tot = 0
    num_success = 0
    
    osw_path = File.expand_path("../test/osw_files/", __FILE__)
  
    osw_files = Dir.entries(osw_path).select {|entry| entry.end_with?(".osw")}
    if File.exists?(File.expand_path("../log", __FILE__))
        FileUtils.rm(File.expand_path("../log", __FILE__))
    end
    
    os_cli = get_os_cli()

    osw_files.each do |osw|

        # Generate osm from osw
        osw_filename = osw
        num_tot += 1
        
        puts "[#{num_tot}/#{osw_files.size}] Regenerating osm from #{osw}..."
        osw = File.expand_path("../test/osw_files/#{osw}", __FILE__)
        osm = File.expand_path("../test/osw_files/run/in.osm", __FILE__)
        command = "\"#{os_cli}\" run -w #{osw} -m >> log"
        for _retry in 1..3
            system(command)
            break if File.exists?(osm)
        end
        if not File.exists?(osm)
            puts "  ERROR: Could not generate osm."
            exit
        end

        # Add auto-generated message to top of file
        file_text = File.readlines(osm)
        File.open(osm, "w") do |f|
            f.write("!- NOTE: Auto-generated from #{osw.gsub(File.dirname(__FILE__), "")}\n")
            file_text.each do |file_line|
                f.write(file_line)
            end
        end

        # Copy to appropriate measure test dirs
        osm_filename = osw_filename.gsub(".osw", ".osm")
        measure_test_dir = File.expand_path("../measures/SimulationOutputReport/tests/", __FILE__)
        if not Dir.exists?(measure_test_dir)
            puts "  ERROR: Could not copy osm to #{measure_test_dir}."
            exit
        end
        FileUtils.cp(osm, File.expand_path("#{measure_test_dir}/#{osm_filename}", __FILE__))
        num_success += 1

        # Clean up
        run_dir = File.expand_path("../test/osw_files/run", __FILE__)
        if Dir.exists?(run_dir)
            FileUtils.rmtree(run_dir)
        end
        if File.exists?(File.expand_path("../test/osw_files/out.osw", __FILE__))
            FileUtils.rm(File.expand_path("../test/osw_files/out.osw", __FILE__))
        end
    end
    
    puts "Completed. #{num_success} of #{num_tot} osm files were regenerated successfully."
    
  end
  
end

desc 'Perform integrity check on inputs for all projects'
task :integrity_check_all do
    integrity_check()
    integrity_check_options_lookup_tsv()
end # rake task

desc 'Perform integrity check on inputs for project_resstock_national'
task :integrity_check_resstock_national do
    integrity_check(['project_resstock_national'])
    integrity_check_options_lookup_tsv()
end # rake task

desc 'Perform integrity check on inputs for project_resstock_pnw'
task :integrity_check_resstock_pnw do
    integrity_check(['project_resstock_pnw'])
    integrity_check_options_lookup_tsv()
end # rake task

desc 'Perform integrity check on inputs for project_resstock_testing'
task :integrity_check_resstock_testing do
    integrity_check(['project_resstock_testing'])
    integrity_check_options_lookup_tsv()
end # rake task

desc 'Perform integrity check on inputs for project_resstock_comed'
task :integrity_check_resstock_comed do
    integrity_check(['project_resstock_comed'])
    integrity_check_options_lookup_tsv()
end # rake task

desc 'Perform integrity check on inputs for project_resstock_efs'
task :integrity_check_resstock_efs do
    integrity_check(['project_resstock_efs'])
    integrity_check_options_lookup_tsv()
end # rake task

def integrity_check(project_dir_names=nil)
  if project_dir_names.nil?
    project_dir_names = get_all_project_dir_names()
  end

  # Load helper file and sampling file
  resources_dir = File.join(File.dirname(__FILE__), 'resources')
  require File.join(resources_dir, 'buildstock')
  require File.join(resources_dir, 'run_sampling')
    
  # Setup
  lookup_file = File.join(resources_dir, 'options_lookup.tsv')
  check_file_exists(lookup_file, nil)
  
  project_dir_names.each do |project_dir_name|
    # Perform various checks on each probability distribution file
    parameters_processed = []
    tsvfiles = {}
    last_size = -1
  
    parameter_names = []
    get_parameters_ordered_from_options_lookup_tsv(resources_dir).each do |parameter_name|
      tsvpath = File.join(project_dir_name, "housing_characteristics", "#{parameter_name}.tsv")
      next if not File.exist?(tsvpath) # Not every parameter used by every project
      parameter_names << parameter_name
    end
    
    while parameters_processed.size != parameter_names.size
    
      if last_size == parameters_processed.size
        # No additional processing occurred during last pass
        unprocessed_parameters = parameter_names - parameters_processed
        err = "ERROR: Unable to process these parameters: #{unprocessed_parameters.join(', ')}."
        deps = []
        unprocessed_parameters.each do |p|
          tsvpath = File.join(project_dir_name, "housing_characteristics", "#{p}.tsv")
          tsvfile = TsvFile.new(tsvpath, nil)
          tsvfile.dependency_cols.keys.each do |d|
            next if deps.include?(d)
            deps << d
          end
        end
        err += "       Perhaps one of these dependency files is missing? #{(deps - unprocessed_parameters - parameters_processed).join(', ')}."
        raise err
      end
      
      last_size = parameters_processed.size
      parameter_names.each do |parameter_name|
        # Already processed? Skip
        next if parameters_processed.include?(parameter_name)
        
        tsvpath = File.join(project_dir_name, "housing_characteristics", "#{parameter_name}.tsv")
        check_file_exists(tsvpath, nil)
        tsvfile = TsvFile.new(tsvpath, nil)
        tsvfiles[parameter_name] = tsvfile
        
        # Dependencies not yet processed? Skip until a subsequent pass
        skip = false
        tsvfile.dependency_cols.keys.each do |dep|
          next if parameters_processed.include?(dep)
          skip = true
        end
        next if skip

        puts "Checking for issues with #{project_dir_name}/#{parameter_name}..."
        parameters_processed << parameter_name
        
        # Test all possible combinations of dependency value combinations
        combo_hashes = get_combination_hashes(tsvfiles, tsvfile.dependency_cols.keys)
        if combo_hashes.size > 0
          combo_hashes.each do |combo_hash|
            _matched_option_name, _matched_row_num = tsvfile.get_option_name_from_sample_number(1.0, combo_hash)
          end
        else
          # global distribution
          _matched_option_name, _matched_row_num = tsvfile.get_option_name_from_sample_number(1.0, nil)
        end
          
      end
    end # parameter_name
    
    # Test sampling
    r = RunSampling.new
    output_file = r.run(project_dir_name, 1000, 'buildstock.csv')
    if File.exist?(output_file)
      File.delete(output_file) # Clean up
    end
    
  end # project_dir_name
  
end

def integrity_check_options_lookup_tsv()

  require 'openstudio'

  # Load helper file and sampling file
  resources_dir = File.join(File.dirname(__FILE__), 'resources')
  require File.join(resources_dir, 'buildstock')
    
  # Setup
  lookup_file = File.join(resources_dir, 'options_lookup.tsv')
  check_file_exists(lookup_file, nil)

  # Integrity checks for option_lookup.tsv
  measures = {}
  model = OpenStudio::Model::Model.new
  
  # Gather all options/arguments
  parameter_names = get_parameters_ordered_from_options_lookup_tsv(resources_dir)
  parameter_names.each do |parameter_name|
    option_names = get_options_for_parameter_from_options_lookup_tsv(resources_dir, parameter_name)
    options_measure_args = get_measure_args_from_option_names(lookup_file, option_names, parameter_name, nil)
    option_names.each do |option_name|
      # Check for (parameter, option) names
      # Get measure name and arguments associated with the option
      options_measure_args[option_name].each do |measure_subdir, args_hash|
        if not measures.has_key?(measure_subdir)
          measures[measure_subdir] = {}
        end
        if not measures[measure_subdir].has_key?(parameter_name)
          measures[measure_subdir][parameter_name] = {}
        end
            
        # Skip options with duplicate argument values as a previous option; speeds up processing.
        duplicate_args = false
        measures[measure_subdir][parameter_name].keys.each do |opt_name|
          next if measures[measure_subdir][parameter_name][opt_name].to_s != args_hash.to_s
          duplicate_args = true
          break
        end
        next if duplicate_args
            
        # Store arguments
        measures[measure_subdir][parameter_name][option_name] = args_hash
            
      end
    end
  end

  max_checks = 1000
  measures.keys.each do |measure_subdir|
    puts "Checking for issues with #{measure_subdir} measure..."

    measurerb_path = File.absolute_path(File.join(File.dirname(lookup_file), 'measures', measure_subdir, 'measure.rb'))
    check_file_exists(measurerb_path, nil)
    measure_instance = get_measure_instance(measurerb_path)

    # Validate measure arguments for each combination of options
    param_names = measures[measure_subdir].keys()
    options_array = []
    param_names.each do |parameter_name|
      options_array << measures[measure_subdir][parameter_name].keys()
    end
    option_combinations = options_array.first.product(*options_array[1..-1])
    
    all_measure_args = []
    max_checks_reached = false
    option_combinations.each_with_index do |option_combination, combo_num|
      if combo_num > max_checks
        max_checks_reached = true
        break
      end
      measure_args = {}
      option_combination.each_with_index do |option_name, idx|
          measures[measure_subdir][param_names[idx]][option_name].each do |k,v|
              measure_args[k] = v
          end
      end
      next if all_measure_args.include?(measure_args)
      all_measure_args << measure_args
    end
    
    all_measure_args.shuffle.each_with_index do |measure_args, idx|
      validate_measure_args(measure_instance.arguments(model), measure_args, lookup_file, measure_subdir, nil)
    end
    
    if max_checks_reached
      puts "Max number of checks (#{max_checks}) reached. Continuing..."
    end
  end
  
end

def get_all_project_dir_names()
    project_dir_names = []
    Dir.entries(File.dirname(__FILE__)).each do |entry|
        next if not Dir.exist?(entry)
        next if not entry.start_with?("project_")
        project_dir_names << entry
    end
    return project_dir_names
end

def get_os_cli
  # Get latest installed version of openstudio.exe
  os_clis = Dir["C:/openstudio-*/bin/openstudio.exe"] + Dir["/usr/bin/openstudio"] + Dir["/usr/local/bin/openstudio"]
  if os_clis.size == 0
      puts "ERROR: Could not find the openstudio binary. You may need to install the OpenStudio Command Line Interface."
      exit
  end
  return os_clis[-1]
end