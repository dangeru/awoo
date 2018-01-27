############################################
# => thread_gc.rb - Thread Garbage Collection for Awoo.
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#
require_relative 'utils.rb'
require 'json'
module ThreadGC
  def self.archive_thread(con, id)
    data = get_thread_replies(id, Hash.new, con, true)
    if data[0] == 400 then
      puts "The board for thread " + id.to_s + " does not exist anymore, not archiving"
      return
    end
    board = data[0][:board]
    title = data[0][:title]
    begin
      con.query("BEGIN")
      query(con, "INSERT INTO archived_posts (post_id, title, board) VALUES (?, ?, ?)", id, title, board)
      query(con, "DELETE FROM posts WHERE post_id = ? OR parent = ?", id, id)
      con.query("COMMIT")
      out = JSON.dump(data)
      File.open 'archive/' + id.to_s + '.json', 'w' do |file|
        file.write out
      end
    rescue Interrupt, SignalException => e
      puts "User cancel, rolling back transaction and dying"
      con.query("ROLLBACK")
      raise e
    rescue Exception => e
      puts "Error archiving thread, rolling back transaction"
      con.query("ROLLBACK")
      puts e
    end
  end
  def self.prune!
    con = make_con()
    AwooUpdater.run(con)
    query(con, "SELECT post_id FROM posts WHERE parent IS NULL AND sticky = 0 AND UNIX_TIMESTAMP(last_bumped) < ?",
          # 20 days
          Time.new.strftime("%s").to_i - (60*60*24*20)).each do |row|
      id = row["post_id"].to_i
      puts "Archiving thread " + id.to_s
      archive_thread(con, id)
      puts "Archived thread " + id.to_s
    end
    puts "All threads pruned"
  end
end
