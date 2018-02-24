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
    burg_total = burg_burg = 0;
    number_of_posts = data.length;
    if (board == "burg") then
      burg_total = number_of_posts
      burg_burg = data.select do |d| d[:comment] == "burg" end.length
    end
    begin
      con.query("BEGIN")
      query(con, "INSERT INTO archived_posts (post_id, title, board, burg_total, burg_burg, number_of_posts) VALUES (?, ?, ?, ?, ?, ?)", id, title, board, burg_total, burg_burg, number_of_posts)
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
    puts "Updating legacy burgs"
    query(con, "SELECT post_id FROM archived_posts WHERE (burg_total IS NULL OR burg_burg IS NULL) AND board = ?", "burg").each do |row|
      id = row["post_id"]
      puts "Updating legacy burg " + id.to_s
      filename = 'archive/' + id.to_s + '.json'
      if not File.exist? filename then
        puts "File " + filename + " does not exist, skipping thread"
        next
      end
      begin
        File.open filename do |file|
          obj = JSON.parse file.read, {:symbolize_names => true}
          burg_total = obj.length
          burg_burg = obj.select do |d| d[:comment] == "burg" end.length
          query(con, "UPDATE archived_posts SET burg_total = ?, burg_burg = ?, number_of_posts = ? WHERE post_id = ?", burg_total, burg_burg, burg_total, id)
        end
      rescue Exception => e
        puts e
      end
    end
    puts "All legacy burgs updated"
    puts "Updating legacy archived threads"
    query(con, "SELECT post_id FROM archived_posts WHERE number_of_posts IS NULL").each do |row|
      id = row["post_id"]
      puts "Updating legacy archived thread " + id.to_s
      filename = 'archive/' + id.to_s + '.json'
      if not File.exist? filename then
        puts "File " + filename + " does not exist, skipping thread"
        next
      end
      begin
        File.open filename do |file|
          obj = JSON.parse file.read, {:symbolize_names => true}
          number_of_posts = obj.length
          query(con, "UPDATE archived_posts SET number_of_posts = ? WHERE post_id = ?", number_of_posts, id)
        end
      rescue Exception => e
        puts e
      end
    end
    puts "All legacy archived threads updated"
  end
end
