 desc 'Show basic controller usage stats'
 task: controllers =>: environment do
     logfiles = Dir['log/%s.log*' % Rails.env].sort
   logs_gz, logs_txt = logfiles.partition {
     | f | Pathname.new(f).extname == '.gz'
   }
 results = `ag Started -A 1 #{logs_txt.join(' ')}`
 unless logs_gz.empty ?
   results << `zcat #{logs_gz.join(' ')} |ag Started -A 1`
 end
 Event = Struct.new(: http_method,: uri_path,: client_ip,: requested_at_str,: controller_name,: controller_action,: format) do
     def requested_at
   Chronic.parse(requested_at_str)
 end
 def action_fmt
   [controller_name, controller_action].join('#')
 end
 end
 events_raw = results.lines.each_cons(2)
 events = events_raw.map {
   | lines |
     next unless lines.first = ~/Started/ && lines.last = ~/Processing/
   # Started GET "/auth/signin"
   for 1.2 .3 .4 at 2018 - 07 - 30 09: 22: 15 - 0400()
   # Processing by UserSessionController #new as HTML()
   started_m = /Started (?<http_method>\w+) "(?<uri_path>[^ ]*)" for (?<client_ip>\d+\.\d+\.\d+\.\d+) at (?<requested_at_str>[^ ]+ [^ ]+ [^ ]+)(?: .*)?/.match(lines.first) & .named_captures
   processing_m = /Processing by (?<controller_name>[^ ]+)#(?<controller_action>\w+) as (?<format>[^ ]+)(?: .*)?/.match(lines.last) & .named_captures
   next
   if started_m.nil ?
     next
   if processing_m.nil ?
     e = Event.new( * started_m.merge(processing_m).values)
   e
 }.compact

 logged_controller_action_events = events.group_by( &: action_fmt)

 defined_controller_actions = []
 Zeitwerk::Loader.eager_load_all
 ApplicationController.descendants.each do |clazz |
     methods = clazz.instance_methods - ApplicationController.instance_methods
   methods.each do |method |
     defined_controller_actions << OpenStruct.new(controller_name: clazz.name, controller_action: method, action_fmt: "#{clazz.name}##{method}")
   end
 end

 all_controller_actions = (logged_controller_action_events.keys + defined_controller_actions.map( &: action_fmt)).compact.uniq.sort

 table = Terminal::Table.new headings: % w[Action Requests Earliest Latest Latest_rel]
 all_controller_actions.each do |controller_action |
     events = logged_controller_action_events[controller_action]
   if events.present ?
   dates = events.map( &: requested_at)
 min_date = dates.min.to_date
 max_date = dates.max
 table << [controller_action, events.count, min_date, max_date, time_ago_in_words(max_date)]
 else
   table << [controller_action, Rainbow('No Log').gray, nil, nil, nil]
 end
 end
 puts table
 end
