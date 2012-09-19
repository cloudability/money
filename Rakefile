require 'rubygems'
require 'rake/clean'

CLOBBER.include('doc', '.yardoc')

def gemspec
  @gemspec ||= begin
    file = File.expand_path("../money.gemspec", __FILE__)
    eval(File.read(file), binding, file)
  end
end


task :default => :spec
task :test => :spec


require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new


require 'yard'

YARD::Rake::YardocTask.new do |t|
  t.options << "--files" << "CHANGELOG.md,LICENSE"
end


require 'rubygems/package_task'

Gem::PackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

task :gem => :gemspec

desc "Install the gem locally"
task :install => :gem do
  sh "gem install pkg/#{gemspec.full_name}.gem"
end

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end


desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -I lib -r money.rb"
end


desc "Assign a more densely packed numeric ID to each currency, facilitating storage as a 1-byte unsigned int.  This should be re-run after any new currency is added."
task :assign_ids do
  # Generate more densely packed numeric IDs for existing currencies.
  # Since we could possibly have a new currency show up in the middle of
  # the pack at some point, we make this a "stable" operation by not
  # re-assigning values arbitrarily but instead assigning new ones as needed.


  # Doing this so we don't raise on the very exception we want to fix...
  require 'json'
  require './lib/money/currency_loader'
  currencies = CurrencyLoader.load_currencies(true)

  require 'json_builder'

  # This is to deal with currencies that show up multiple times,
  # sometimes with a different key, and no iso numeric code.
  id_by_iso_code = {}
  counter = currencies.values.map { |currency| currency[:id] || 0 }.sort.max + 1

  table_by_id =
    currencies.
      map { |key, currency| currency[:key] = key; currency }.
      sort { |a, b| a[:key] <=> b[:key] }.
      map do |currency|
        if(currency[:id].nil?)
          if(id_by_iso_code.has_key?(currency[:iso_code]))
            currency[:id] = id_by_iso_code[currency[:iso_code]]
          else
            id_by_iso_code[currency[:iso_code]] = counter
            currency[:id] = counter
            counter += 1
          end
        end
        [currency[:key], currency[:id]]
      end

  json = JSONBuilder::Compiler.generate(:pretty => true) do
    table_by_id.each do |key_id|
      key key_id[0].to_sym, key_id[1]
    end
  end
  File.open("config/currency_ids.json", "wb") do |fh|
    fh.write json
    fh.write "\n"
  end
end
