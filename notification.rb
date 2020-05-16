require "mattermost"
#require "gmt-tools-config"

class Notification
  def initialize
    config = GmtToolsConfig.instance
    @mm = config.mm_client
    @me = @mm.get_me.body
  end

  def mm_direct_message_by_username(username, message)
    req = @mm.get_user_by_username(username)
    if !req.success?
      raise req.body["message"]
    end
    user = req.body
    mm_direct_message(user["id"], message)
  end
  
  def mm_direct_message(userid, message)
    req = @mm.create_direct_channel(@me["id"], userid)
    if !req.success?
      raise req.body["message"]
    end
    dm_ch = req.body
    mm_post(dm_ch["id"], message)
  end

  def mm_post(channel_id, message)
    data = {channel_id: channel_id, message: message}
    req = @mm.create_post(data)
    if !req.success?
      raise req.body["message"]
    end
  end
end
