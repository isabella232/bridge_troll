require 'libhoney'

# Once you've signed up, find your Honeycomb Write Key at https://ui.honeycomb.io/account
$honeycomb = Libhoney::Client.new(:writekey => "YOUR_WRITE_KEY",
                                  :dataset => "rails")

ActiveSupport::Notifications.subscribe /process_action.action_controller/ do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  # These are the keys we're interested in! Intentionally omitting :headers and
  # :params
  data = event.payload.slice(:controller, :action, :method, :path, :format, :status, :db_runtime, :view_runtime)

  if !data[:format] || data[:format] == "format:*/*"
    data[:format] = "all"
  end
  data[:duration_ms] = event.duration

  # Pull off any other metadata we attached along the way
  data = data.merge(event.payload[:metadata])

  $honeycomb.send_now(data)
end

ActiveSupport::Notifications.subscribe /sql.active_record/ do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  data = event.payload.slice(:name, :connection_id)
  data[:sql] = event.payload[:sql].strip
  # hrm, this may cause some excessive column proliferation...
  event.payload[:binds].each do |b|
    data["bind_#{ b.name }".to_sym] = b.value
  end
  data[:type] = event.name
  data[:duration] = event.duration

  data[:local_stack] = caller.select{|e| e.include?(Rails.root.to_s)}

  # Send these events to a different dataset
  event = $honeycomb.event
  event.dataset = "active_record"
  event.add(data)
  event.send
end
