HoneycombRails.configure do |conf|
  conf.writekey = ENV['HONEYCOMB_WRITEKEY'] or raise "Missing HONEYCOMB_WRITEKEY!"
  conf.dataset = ENV['HONEYCOMB_DATASET'] || 'bridge-troll'
  conf.db_dataset = ENV['HONEYCOMB_DB_DATASET'] || 'bridge-troll-db'
end
