puts "Loading #{__FILE__}"
# put overrides in '_irbrc'
IRB.conf[:HISTORY_FILE] = "tmp/.irb_history"
IRB.conf[:HISTORY] = -1 # all of it