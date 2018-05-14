############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2018
#

require 'mysql2'

require_relative 'utils'

API = "/api/v2"

module Sinatra
  module Awoo
    module Routing
      module Boards
        def self.registered(app)
          # Load up the config.json and read out some variables
          hostname = Config.get["hostname"]
          app.set :config, Config.get
          # Load all the boards out of the config file
          boards = []
          Config.get['boards'].each do |key, array|
            puts "Loading board " + Config.get['boards'][key]['name'] + "..."
            boards << Config.get['boards'][key]['name']
          end
          script = nil;
          # Route for making a new OP
          app.post "/post" do
            con = make_con()
            # OPs have a board, a title and a comment.
            board = params[:board]
            title = params[:title]
            content = params[:comment]
            # Also pull the IP address from the request and check if it looks like spam
            ip = get_ip(request, env);
            if looks_like_spam(con, ip, env) then
              return [429, "Flood detected, post discarded"]
            elsif (title.length > 180 or content.length > 500) and not session[:moderates] then
              return [431, "Post or title too long (over 500 characters)"]
            elsif Config.get["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            elsif board == "all"
              return [400, "stop that"]
            end
            title = apply_word_filters(board, title)
            content = apply_word_filters(board, content)
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then
              return erb :banned, :locals => {:info => banned, :config => Config.get}
            end
            # Insert the new post into the database
            if params[:capcode] and params[:capcode].length > 0 and allowed_capcodes(session).include? params[:capcode] and session[:username] then
              capcode = params[:capcode];
              capcode += capcode == "_hidden" ? "" : (":" + session[:username])
              query(con, "INSERT INTO posts (board, title, content, ip, janitor) VALUES (?, ?, ?, ?, ?)", board, title, content, ip, capcode);
            else
              query(con, "INSERT INTO posts (board, title, content, ip) VALUES (?, ?, ?, ?)", board, title, content, ip);
            end
            # Then get the ID of the just-inserted post and redirect the user to their new thread
            query(con, "SELECT LAST_INSERT_ID() AS id").each do |res|
              href = "/" + params[:board] + "/thread/" + res["id"].to_s + "?watch=true"
              redirect(href, 303);
            end
            # if there was no "most-recently created post" then we probably have a bigger issue than a failed post
            return "Error? idk"
          end
          # Route for replying to an OP
          app.post "/reply" do
            con = make_con()
            # replies have a board, a comment and a parent (the post they're responding to)
            board = params[:board]
            content = params[:content]
            content = apply_word_filters(board, content)
            parent = params[:parent].to_i
            if make_metadata(con, parent, session)[:number_of_replies] >= Config.get["bump_limit"]
              return [400, "Bump limit reached"]
            end
            if content.length > 500 and not session[:moderates] then
              return [431, "Reply too long (over 500 characters)"]
            end
            # Pull the IP address and check if it looks like spam
            ip = get_ip(request, env);
            if looks_like_spam(con, ip, env) then
              return [429, "Flood detected, post discarded"]
            end
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then
              return erb :banned, :locals => {:info => banned, :config => Config.get}
            end
            closed = nil
            query(con, "SELECT is_locked FROM posts WHERE post_id = ?", parent).each do |res|
              closed = res["is_locked"]
            end
            if closed == nil then
              return [400, "That thread doesn't exist"]
            elsif closed != 0 then
              return [400, "That thread has been closed"]
            elsif Config.get["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            end
            # Insert the new reply
            if params[:capcode] and params[:capcode].length > 0 and allowed_capcodes(session).include? params[:capcode] and session[:username] then
              capcode = params[:capcode];
              capcode += capcode == "_hidden" ? "" : (":" + session[:username])
              query(con, "INSERT INTO posts (board, parent, content, ip, title, janitor) VALUES (?, ?, ?, ?, NULL, ?)", board, parent, content, ip, capcode)
            else
              query(con, "INSERT INTO posts (board, parent, content, ip, title) VALUES (?, ?, ?, ?, NULL)", board, parent, content, ip)
            end
            # Mark the parent as bumped
            query(con, "UPDATE posts SET last_bumped = CURRENT_TIMESTAMP() WHERE post_id = ?", parent);
            # needed for dashchan extension
            id = nil
            query(con, "SELECT LAST_INSERT_ID() AS id").each do |res|
              id = res["id"]
            end
            if params[:redirect] == "true"
              return redirect "/" + board + "/thread/" + parent.to_s
            else
              return [200, "OK/" + id.to_s]
            end
          end

          # Each board has a listing of the posts there (board.erb) and a listing of the replies to a give post (thread.erb)
          boards.each do |path|
            app.get "/" + path + "/?" do
              con = make_con()
              if not params[:page]
                offset = 0;
              else
                offset = params[:page].to_i * 20;
              end
              if Config.get["boards"][path]["hidden"] and not session["username"] then
                return [404, erb(:notfound)]
              end
              ress = nil
              if path == "all" then
                ress = get_all(params, session, offset)
              else
                ress = get_board(path, params, session, offset)
              end
              erb :board, :locals => {:path => path, :config => Config.get, :con => con, :offset => offset, :banner => new_banner(path), :moderator => is_moderator(path, session), :session => session, :page => params[:page].to_i, :archive => false, :ress => ress, :page_url_generator => Default_page_generator, :request => request, :params => params, :count => posts_count(con, path), :popular => false}
            end
            app.get "/archive/" + path + "/?" do
              con = make_con()
              if not params[:page]
                offset = 0;
              else
                offset = params[:page].to_i * 20;
              end
              if Config.get["boards"][path]["hidden"] and not session["username"] then
                return [404, erb(:notfound)]
              end
              erb :board, :locals => {:path => path, :config => Config.get, :con => con, :offset => offset, :banner => new_banner(path), :moderator => false, :session => Hash.new, :page => params[:page].to_i, :archive => true, :ress => get_archived_board(con, path, offset), :page_url_generator => Archive_page_generator, :request => request, :params => params, :count => archived_posts_count(con, path), :popular => false}
            end
            app.get "/" + path + "/thread/:id" do |id|
              con = make_con()
              if Config.get["boards"][path]["hidden"] and not session["username"] then
                return [404, erb(:notfound)]
              end
              if does_thread_exist(id, path, con)
                erb :thread, :locals => {:config => Config.get, :path => path, :id => id, :con => con, :banner => new_banner(path), :moderator => is_moderator(path, session), :session => session, :params => params, :replies => get_thread_replies(id.to_i.to_s, session, con), :archived => false, :your_hash => make_hash(get_ip(request, env), id)}
              elsif does_archived_thread_exist(id, path, con)
                erb :thread, :locals => {:config => Config.get, :path => path, :id => id, :con => con, :banner => new_banner(path), :moderator => false, :session => Hash.new, :params => Hash.new, :replies => get_archived_thread_replies(id.to_i), :archived => true, :your_hash => "FFFFFF"}
              else
                return [404, erb(:notfound)]
              end
            end
            # Rules & Editing rules
            app.get "/" + path + "/rules/?" do
              if Config.get["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :rules, :locals => {:rules => Config.get['boards'][path]['rules'], :moderator => is_moderator(path, session), :path => path, :banner => new_banner(path), :config => Config.get, :session => session}
            end
            app.post "/" + path + "/rules/edit/?" do
              if is_moderator(path, session) and has_permission(session, "edit_rules")
                con = make_con();
                # insert an IP note with the changes
                content = "Updated rules for /" + path + "/\n"
                content += wrap("old rules", Config.get['boards'][path]["rules"]);
                content += wrap("new rules", params[:rules])
                query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", "_meta", content, session[:username])
                # change the rules and save the changes
                Config.get['boards'][path]['rules'] = params[:rules]
                Config.rewrite!
                redirect "/" + path + "/rules"
              else
                return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
              end
            end

            # edit word filters form
            app.get "/" + path + "/word-filter/?" do
              if not is_moderator(path, session) or not has_permission(session, "edit_wordfilters") then
                return [404, erb(:notfound)]
              end
              erb :word_filter, :locals => {:config => Config.get, :path => path, :banner => new_banner(path)}
            end

            # posted url when saving word filters
            app.post "/" + path + "/word-filter/?" do
              con = make_con()
              if is_moderator(path, session) and has_permission(session, "edit_wordfilters") then
                # update and save the word filters
                old_words = Config.get['boards'][path]['word-filter'];
                Config.get['boards'][path]['word-filter'] = JSON.parse(params[:words])
                Config.rewrite!
                # save an IP note
                content = "Updated word filters for /" + path + "/\n"
                content += wrap("old word filters", JSON.pretty_generate(old_words));
                content += wrap("new word filters", JSON.pretty_generate(Config.get['boards'][path]["word-filter"]));
                query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", "_meta", content, session[:username])
                return "OK"
              else
                return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
              end
            end
          end

          app.get "/archive/?" do
            con = make_con()
            if not params[:page]
              offset = 0;
            else
              offset = params[:page].to_i * 20;
            end
              erb :board, :locals => {:path => "all", :config => Config.get, :con => con, :offset => offset, :banner => new_banner("all"), :moderator => false, :session => Hash.new, :page => params[:page].to_i, :archive => true, :ress => get_all_archived(con, offset), :page_url_generator => Archive_page_generator, :request => request, :params => params, :count => archived_posts_count(con, "all"), :popular => false}
          end

          # Route for moderators to delete a post (and all of its replies, if it's an OP)
          app.get "/delete/:post_id" do |post_id|
            con = make_con()
            board = nil;
            post_id = post_id.to_i
            parent = nil
            ip = post_content = title = nil
            # First, figure out which board that post is on
            # TODO refactor to use the unified load interface
            query(con, "SELECT content, title, ip, board, parent FROM posts WHERE post_id = ?", post_id).each do |res|
              board = res["board"]
              parent = res["parent"]
              title = res["title"]
              ip = res["ip"]
              board = res["board"]
              post_content = res["content"]
            end
            if board.nil? then
              return [400, "Could not find a post with that ID"]
            end
            # Then, check if the currently logged in user has permission to moderate that board
            if not is_moderator(board, session) or not has_permission(session, "delete")
              return [403, "You are not logged in or you do not have permissions to perform this action on board " + board]
            end
            # Insert an IP note with the content of the deleted post
            content = ""
            if title then
              content += "Post deleted\n"
              content += "Board: " + board + "\n"
              content += wrap("title", title)
            else
              content += "Reply deleted\n"
              content += "Was a reply to /" + board + "/" + parent.to_s + "\n"
            end
            content += wrap("comment", post_content)
            query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", ip, content, session[:username]) unless ip.nil?
            # Finally, delete the post
            query(con, "DELETE FROM posts WHERE post_id = ? OR parent = ?", post_id, post_id)
            if parent != nil then
              href = "/" + board + "/thread/" + parent.to_s
              redirect(href, 303);
            else
              return "Success, probably."
            end
          end

          app.get "/mobile/?" do
            redirect("/", 303);
          end

          # Legacy api, see https://github.com/naomiEve/dangeruAPI
          app.get "/api.php" do
            content_type 'application/json'
            limit = params[:ln].to_i
            if not limit or limit == 0 then
              limit = 10000
            end
            if params[:type] == "thread"
              id = params[:thread].to_i
              result = {:meta => [], :replies => []}
              #limit += 1
              get_thread_replies(id, session).each do |res|
                if res[:is_op] then
                  result[:meta] = [{
                    "title": res[:title],
                    "id": res[:post_id].to_s,
                    "url": "https://" + hostname + "/" + res[:board] + "/thread/" + res[:post_id].to_s
                  }]
                end
                result[:replies].push({"post": res[:comment]})
              end
              result[:replies] = result[:replies][0..limit]
              JSON.dump(result)
            elsif params[:type] == "index"
              # type must be index
              result = {:board => [{
                :name => Config.get["boards"][params[:board]]["name"],
                :url => "https://" + hostname + "/" + params[:board]
              }], :threads => []}
              get_board(params[:board], params, session).each do |res|
                result[:threads].push({
                  :id => res[:post_id],
                  :title => res[:title],
                  :url => "https://" + hostname + "/" + res[:board] + "/thread/" + res[:post_id].to_s
                })
              end
              result[:threads] = result[:threads][0..limit]
              JSON.dump(result)
            else
              return [400, JSON.dump({:error => 404, :message => "The request was malformed / unknown type of request."})]
            end
          end

          # Moderator log in page, (mod_login.erb)
          app.get "/mod" do
            if session[:moderates] then
              return erb :mod_login_success, :locals => {:session => session, :config => Config.get}
            end
            erb :mod_login, :locals => {:session => session, :config => Config.get}
          end
          # Moderator log in action, checks the username and password against the list of janitors and logs them in if it matches
          app.post "/mod" do
            username = params[:username]
            password = params[:password]
            return try_login(username, password, session, params)
          end
          # Logout action, logs the user out and redirects to the mod login page
          app.get "/logout" do
            session[:moderates] = nil
            session[:username] = nil
            redirect("/mod", 303);
          end
          # Gets all post by IP, and lets you ban it
          app.get "/ip/:addr" do |addr|
            if not session[:moderates] or not has_permission(session, "view_ips") then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
            if addr == "_meta" and not has_permission(session, "introspect") then
              return [403, "You don't have the permissions to perform this action."]
            end
            con = make_con()
            erb :ip_list, :locals => {:session => session, :addr => addr, :con => con, :config => Config.get}
          end

          # Gets the moderator ban list
          app.get "/bans" do
            if not session[:moderates] or not has_permission(session, "view_all_bans") then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end

            con = make_con()
            erb :ban_list, :locals => {:con => con, :config => Config.get}
          end

          # Either locks or unlocks the specified thread
          app.get "/lock/:post/?" do |post|
            con = make_con()
            return lock_or_unlock(post, true, con, session)
          end
          app.get "/unlock/:post/?" do |post|
            con = make_con()
            return lock_or_unlock(post, false, con, session)
          end

          # Moves thread from board to board
          app.get "/move/:post/?" do |post|
            if session[:moderates] and has_permission(session, "move") then
              erb :move, :locals => {:post => post, :boards => boards}
            else
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
          end
          app.post "/move/:post/?" do |post|
            con = make_con()
            # We allow the move if the person moderates the board the thread is being moved *from*
            # we don't check the thread that it's being moved *to*
            prev_board = nil;
            query(con, "SELECT board FROM posts WHERE post_id = ?", post).each do |res|
              prev_board = res["board"]
            end
            if is_moderator(prev_board, session) and has_permission(session, "move")
              id = post.to_i
              board = params[:board]
              query(con, "UPDATE posts SET board = ? WHERE post_id = ? OR parent = ?", board, id, id)
              href = "/" + board + "/thread/" + id.to_s
              redirect href
            else
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
          end

          # Leave notes on an ip address
          app.post "/ip_note/:addr" do |addr|
            con = make_con()
            if session[:moderates] == nil or not has_permission(session, "view_ips") then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
            content = params[:content]
            query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", addr, content, session[:username])
            #return redirect("/ip/" + addr, 303)
            return [200, "OK"]
          end

          # Sticky / Unsticky posts
          app.get "/sticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, true, con, session)
          end
          app.post "/sticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, params[:stickyness].to_i, con, session)
          end
          app.get "/unsticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, false, con, session)
          end
          app.get "/uncapcode/:post/?" do |post|
            if not session[:moderates] then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
            post = post.to_i
            con = make_con()
            res = nil
            query(con, "select * from posts where post_id = ?", post).each do |ress| res = ress end
            if not res
              return [400, "That post does not exist"]
            end
            res = make_metadata_from_hash(res, session);
            if ((res[:capcode] == "_hidden" and res[:ip] == get_ip(request, env)) or res[:capcode].split(":")[1] == session[:username]) then
              query(con, "update posts set janitor = null where post_id = ?", post)
              return redirect("/" + res[:board] + "/thread/" + (res[:parent] ? res[:parent] : post).to_s + "#comment-" + post.to_s)
            else
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
          end
          app.get "/capcode/:post/?" do |post|
            if not session[:moderates] then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
            if not params[:capcode] then
              return [400, "Missing capcode parameter"]
            end
            if not allowed_capcodes(session).include?(params[:capcode]) then
              return [403, "You do not have the permission to use any capcode other than these: " + JSON.dump(allowed_capcodes(session))]
            end
            post = post.to_i
            con = make_con()
            res = nil
            query(con, "select * from posts where post_id = ?", post).each do |ress| res = ress end
            if not res
              return [400, "That post does not exist"]
            end
            res = make_metadata_from_hash(res, session);
            capcode = params[:capcode]
            if capcode != "_hidden" then
              capcode += ":" + session[:username]
            end
            query(con, "update posts set janitor = ? where post_id = ?", capcode, post)
            return redirect("/" + res[:board] + "/thread/" + (res[:parent] ? res[:parent] : post).to_s + "#comment-" + post.to_s)
          end

          # Ban / Unban an IP
          app.post "/ban/:ip" do |ip|
            con = make_con()
            if is_moderator(params[:board], session) and has_permission(session, "ban") then
              # Insert the ban
              board = params[:board]
              old_date = params[:date].split('/')
              date = old_date[2] + "-" + old_date[0] + "-" + old_date[1] + " 00:00:00"
              reason = params[:reason]
              query(con, "INSERT INTO bans (ip, board, date_of_unban, reason) VALUES (?, ?, ?, ?)", ip, board, date, reason);
              # Insert the IP note
              content = "Banned from /" + board + "/ until " + params[:date] + "\n"
              content += wrap("reason", reason)
              query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", ip, content, session[:username])
              return "OK"
            else
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
          end
          app.post "/unban/:ip" do |ip|
            con = make_con()
            if is_moderator(params[:board], session) and has_permission(session, "ban") then
              board = params[:board]
              # delete the ban and insert the ip note
              query(con, "DELETE FROM bans WHERE ip = ? AND board = ?", ip, board)
              query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", ip, "Unbanned from /" + board + "/", session[:username])
              return "OK"
            else
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
          end
          app.get "/introspect/?" do
            if not has_permission(session, "introspect") then
              return [403, "You don't have permissions to perform this action."]
            end
            erb :introspect, :locals => {:config => Config.get}
          end
          app.get "/introspect/:mod/?" do |mod|
            if not has_permission(session, "introspect") then
              return [403, "You don't have permissions to perform this action."]
            end
            erb :introspect_selected, :locals => {:config => Config.get, :con => make_con(), :mod => mod}
          end
          # Posted to reset the password of a moderator
          app.post "/introspect_reset" do
            if not has_permission(session, "introspect") then
              return [403, "You don't have permissions to perform this action."]
            end
            if not params[:mod] or not params[:newpass] then
              return [400, "Username or new password not specified"]
            end
            found = -1;
            Config.get["janitors"].length.times do |i|
              if Config.get["janitors"][i]["username"] == params[:mod] then
                found = i
                Config.get["janitors"][i]["password"] = params[:newpass]
                Config.rewrite!
                # rerun will detect that this file has changed and restart the server
                File.open("_watch", "w") do |f|
                  f.write(Random.rand.hash.to_s)
                end
                Process.kill 9, Process.pid # just to be safe
                # if you set up rack to persist sessions over reboots, this will all be pointless
                # because reseting a rouge janitor's password won't log out their existing sessions
                break
              end
            end
            if found == -1 then
              return [400, "Moderator with username " + params[:mod] + " could not be found in config[\"janitors\"]"]
            end
            return [200, "OK"]
          end
          app.get "/search/?" do
            erb :search, :locals => {:banner => new_banner("all")}
          end
          app.get "/search_results/?" do
            con = make_con()
            if not params[:page]
              offset = 0;
            else
              offset = params[:page].to_i * 20;
            end
            (ress, count) = get_search_results(params, con, offset, session)
            erb :board, :locals => {:path => params[:board_select], :config => Config.get, :con => con, :offset => offset, :banner => new_banner("all"), :moderator => is_moderator("all", session), :session => session, :page => params[:page].to_i, :archive => false, :ress => ress, :page_url_generator => Search_page_generator, :request => request, :params => params, :count => count, :popular => false}
          end
          app.get "/advanced_search_results/?" do
            con = make_con()
            if not params[:page]
              offset = 0;
            else
              offset = params[:page].to_i * 20;
            end
            (ress, count) = get_search_results(params, con, offset, session, true)
            erb :advanced_search_results, :locals => {:ress => ress, :count => count, :page_url_generator => Search_page_generator_advanced, :page => params[:page].to_i}
          end
          app.get "/popular/?" do
            con = make_con()
            if not params[:page]
              offset = 0;
            else
              offset = params[:page].to_i * 20;
            end
            bds = nil
            begin
              bds = JSON.parse(params[:boards])
            rescue
              bds = nil
            end
            if not bds then
              bds = boards
            end
            ress = get_popular(con, bds, session, offset)
            count = get_popular_count(con, bds, session)
            erb :board, :locals => {:path => "all", :config => Config.get, :con => con, :offset => offset, :banner => new_banner("all"), :moderator => is_moderator("all", session), :session => session, :page => params[:page].to_i, :archive => false, :ress => ress, :page_url_generator => Popular_page_generator, :request => request, :params => params, :count => count, :popular => bds}
          end
          # thanks cloudflare
          app.get "/userscript_no_cache/?" do
            headers "Cache-Control" => "max-age=60"
            content_type "application/javascript"
            if not script then
              File.open "static/static/awoo-catalog.user.js", "r" do |contents|
                script = contents.read
              end
            end
            script
          end
          app.get "/pull/?" do
            if not session[:moderates] then
              return [404, erb(:notfound)]
            end
            system("git pull")
          end
          app.after do
            if (Random.rand * 100).round == 92 then
              start = Time.new
              100.times do GC.start end
              puts "Garbage collection took #{1000 * (Time.new - start)}ms"
            end
          end
        end
      end
    end
  end
end
