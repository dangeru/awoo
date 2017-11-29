############################################
# => boards.rb - Board Renderer
# => Awoo Textboard Engine
# => (c) prefetcher & github commiters 2017
#

require 'mysql2'
require 'sanitize'

require_relative 'utils'

API = "/api/v2"

module Sinatra
  module Awoo
    module Routing
      module Boards
        def self.registered(app)
          # Load up the config.json and read out some variables
          config_raw = File.read('config.json')
          config = JSON.parse(config_raw)
          hostname = config["hostname"]
          app.set :config, config
          # Load all the boards out of the config file
          boards = []
          config['boards'].each do |key, array|
            puts "Loading board " + config['boards'][key]['name'] + "..."
            boards << config['boards'][key]['name']
          end
          # Route for making a new OP
          app.post "/post" do
            con = make_con()
            # OPs have a board, a title and a comment.
            board = params[:board]
            title = params[:title]
            content = params[:comment]
            # Also pull the IP address from the request and check if it looks like spam
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [429, "Flood detected, post discarded"]
            elsif title.length > 500 or content.length > 500 then
              return [431, "Post too long (over 500 characters)"]
            elsif config["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            elsif board == "all"
              return [400, "stop that"]
            end
            title = apply_word_filters(config, board, title)
            content = apply_word_filters(config, board, content)
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then
              return erb :banned, :locals => {:info => banned, :config => config}
            end
            # Insert the new post into the database
            if params[:capcode] and params[:capcode].length > 0 and allowed_capcodes(session, config).include? params[:capcode] and session[:username] then
              query(con, "INSERT INTO posts (board, title, content, ip, janitor) VALUES (?, ?, ?, ?, ?)", board, title, content, ip, params[:capcode] + ":" + session[:username]);
            else
              query(con, "INSERT INTO posts (board, title, content, ip) VALUES (?, ?, ?, ?)", board, title, content, ip);
            end
            # Then get the ID of the just-inserted post and redirect the user to their new thread
            query(con, "SELECT LAST_INSERT_ID() AS id").each do |res|
              href = "/" + params[:board] + "/thread/" + res["id"].to_s
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
            content = apply_word_filters(config, board, content)
            parent = params[:parent].to_i
            if make_metadata(con, parent, session, config)[:number_of_replies] >= config["bump_limit"]
              return [400, "Bump limit reached"]
            end
            if content.length > 500 then
              return [431, "Reply too long (over 500 characters)"]
            end
            # Pull the IP address and check if it looks like spam
            ip = get_ip(con, request, env);
            if looks_like_spam(con, ip, env, config) then
              return [429, "Flood detected, post discarded"]
            end
            # Check if the IP is banned
            banned = get_ban_info(ip, board, con)
            if banned then
              return erb :banned, :locals => {:info => banned, :config => config}
            end
            closed = nil
            query(con, "SELECT is_locked FROM posts WHERE post_id = ?", parent).each do |res|
              closed = res["is_locked"]
            end
            if closed == nil then
              return [400, "That thread doesn't exist"]
            elsif closed != 0 then
              return [400, "That thread has been closed"]
            elsif config["boards"][board]["hidden"] and not session[:username]
              return [403, "You have no janitor permissions"]
            end
            # Insert the new reply
            if params[:capcode] and params[:capcode].length > 0 and allowed_capcodes(session, config).include? params[:capcode] and session[:username] then
              query(con, "INSERT INTO posts (board, parent, content, ip, title, janitor) VALUES (?, ?, ?, ?, NULL, ?)", board, parent, content, ip, params[:capcode] + ":" + session[:username])
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
              if config["boards"][path]["hidden"] and not session["username"] then
                #return [403, "You have no janitor privileges"]
                return [404, erb(:notfound)]
              end
              erb :board, :locals => {:path => path, :config => config, :con => con, :offset => offset, :banner => new_banner(path), :moderator => is_moderator(path, session), :session => session, :page => params[:page].to_i}
            end
            app.get "/" + path + "/thread/:id" do |id|
              con = make_con()
              if config["boards"][path]["hidden"] and not session["username"] then
                #return [403, "You have no janitor privileges"]
                return [404, erb(:notfound)]
              end
              if does_thread_exist(id, path)
                erb :thread, :locals => {:config => config, :path => path, :id => id, :con => con, :banner => new_banner(path), :moderator => is_moderator(path, session), :session => session}
              else
                return [404, erb(:notfound)]
              end
            end

            # Rules & Editing rules
            app.get "/" + path + "/rules/?" do
              if config["boards"][path]["hidden"] and not session["username"] then
                return [403, "You have no janitor privileges"]
              end
              erb :rules, :locals => {:rules => settings.config['boards'][path]['rules'], :moderator => is_moderator(path, session), :path => path, :banner => new_banner(path), :config => config, :session => session}
            end
            app.post "/" + path + "/rules/edit/?" do
              if is_moderator(path, session) and has_permission(session, config, "edit_rules")
                con = make_con();
                # insert an IP note with the changes
                content = "Updated rules for /" + path + "/\n"
                content += wrap("old rules", settings.config['boards'][path]["rules"]);
                content += wrap("new rules", params[:rules])
                query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", "_meta", content, session[:username])
                # change the rules and save the changes
                settings.config['boards'][path]['rules'] = params[:rules]
                File.open("config.json", "w") do |f|
                  f.write(JSON.pretty_generate(settings.config))
                end
                redirect "/" + path + "/rules"
              else
                return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
              end
            end
            # edit word filters form
            app.get "/" + path + "/word-filter/?" do
              if not is_moderator(path, session) or not has_permission(session, config, "edit_wordfilters") then
                return [404, erb(:notfound)]
              end
              erb :word_filter, :locals => {:config => config, :path => path, :banner => new_banner(path)}
            end
            # posted url when saving word filters
            app.post "/" + path + "/word-filter/?" do
              con = make_con()
              if is_moderator(path, session) and has_permission(session, config, "edit_wordfilters") then
                # update and save the word filters
                old_words = settings.config['boards'][path]['word-filter'];
                settings.config['boards'][path]['word-filter'] = JSON.parse(params[:words])
                File.open("config.json", "w") do |f|
                  f.write(JSON.pretty_generate(settings.config))
                end
                # save an IP note
                content = "Updated word filters for /" + path + "/\n"
                content += wrap("old word filters", JSON.pretty_generate(old_words));
                content += wrap("new word filters", JSON.pretty_generate(config['boards'][path]["word-filter"]));
                query(con, "INSERT INTO ip_notes (ip, content, actor) VALUES (?, ?, ?)", "_meta", content, session[:username])
                return "OK"
              else
                return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
              end
            end
          end

          # Route for moderators to delete a post (and all of its replies, if it's an OP)
          app.get "/delete/:post_id" do |post_id|
            con = make_con()
            board = nil;
            post_id = post_id.to_i
            parent = nil
            ip = post_content = title = nil
            # First, figure out which board that post is on
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
            if not is_moderator(board, session) or not has_permission(session, config, "delete")
              return [403, "You are not logged in or you do not have permissions to perform this action on board " + board]
            end
            # Insert an IP note with the content of the deleted post
            content = ""
            if title then
              content += "Post deleted\n"
              content += wrap("title", title)
            else
              content += "Reply deleted\n"
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

          # Legacy api, see https://github.com/naomiEve/dangeruAPI
          app.get "/api.php" do
            limit = params[:ln].to_i
            if not limit or limit == 0 then
              limit = 10000
            end
            if params[:type] == "thread"
              id = params[:thread].to_i
              result = {:meta => [], :replies => []}
              #limit += 1
              get_thread_replies(id, session, config).each do |res|
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
                :name => config["boards"][params[:board]]["name"],
                :url => "https://" + hostname + "/" + params[:board]
              }], :threads => []}
              get_board(params[:board], params, session, config).each do |res|
                result[:threads].push({
                  :id => res[:post_id],
                  :title => res[:title],
                  :url => "https://" + hostname + "/" + res[:board] + "/thread/" + res[:post_id].to_s
                })
              end
              result[:threads] = result[:threads][0..limit]
              JSON.dump(result)
            else
              return [400, "The request was malformed / unknown type of request."]
            end
          end

          # Moderator log in page, (mod_login.erb)
          app.get "/mod" do
            if session[:moderates] then
              return erb :mod_login_success, :locals => {:session => session, :config => config}
            end
            erb :mod_login, :locals => {:session => session, :config => config}
          end
          # Moderator log in action, checks the username and password against the list of janitors and logs them in if it matches
          app.post "/mod" do
            username = params[:username]
            password = params[:password]
            return try_login(username, password, config, session, params)
          end
          # Logout action, logs the user out and redirects to the mod login page
          app.get "/logout" do
            session[:moderates] = nil
            session[:username] = nil
            redirect("/mod", 303);
          end
          # Gets all post by IP, and let's you ban it
          app.get "/ip/:addr" do |addr|
            if not session[:moderates] or not has_permission(session, config, "view_ips") then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end
            if addr == "_meta" and not has_permission(session, config, "introspect") then
              return [403, "You don't have the permissions to perform this action."]
            end
            con = make_con()
            erb :ip_list, :locals => {:session => session, :addr => addr, :con => con, :config => config}
          end

          # Gets the moderator ban list
          app.get "/bans" do
            if not session[:moderates] or not has_permission(session, config, "view_all_bans") then
              return [403, "You have no janitor privileges or you don't have the permissions to perform this action."]
            end

            con = make_con()
            erb :ban_list, :locals => {:con => con, :config => config}
          end

          # Either locks or unlocks the specified thread
          app.get "/lock/:post/?" do |post|
            con = make_con()
            return lock_or_unlock(post, true, con, session, config)
          end
          app.get "/unlock/:post/?" do |post|
            con = make_con()
            return lock_or_unlock(post, false, con, session, config)
          end

          # Moves thread from board to board
          app.get "/move/:post/?" do |post|
            if session[:moderates] and has_permission(session, config, "move") then
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
            if is_moderator(prev_board, session) and has_permission(session, config, "move")
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
            if session[:moderates] == nil or not has_permission(session, config, "view_ips") then
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
            sticky_unsticky(post_id, true, con, session, config)
          end
          app.post "/sticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, params[:stickyness].to_i, con, session, config)
          end
          app.get "/unsticky/:id/?" do |post_id|
            con = make_con()
            sticky_unsticky(post_id, false, con, session, config)
          end

          # Ban / Unban an IP
          app.post "/ban/:ip" do |ip|
            con = make_con()
            if is_moderator(params[:board], session) and has_permission(session, config, "ban") then
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
            if is_moderator(params[:board], session) and has_permission(session, config, "ban") then
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
            if not has_permission(session, config, "introspect") then
              return [403, "You don't have permissions to perform this action."]
            end
            erb :introspect, :locals => {:config => config}
          end
          app.get "/introspect/:mod/?" do |mod|
            if not has_permission(session, config, "introspect") then
              return [403, "You don't have permissions to perform this action."]
            end
            erb :introspect_selected, :locals => {:config => config, :con => make_con(), :mod => mod}
          end
          # Posted to reset the password of a moderator
          app.post "/introspect_reset" do
            if not has_permission(session, config, "introspect") then
              return [403, "You don't have permissions to perform this action."]
            end
            if not params[:mod] or not params[:newpass] then
              return [400, "Username or new password not specified"]
            end
            found = -1;
            config["janitors"].length.times do |i|
              if config["janitors"][i]["username"] == params[:mod] then
                found = i
                config["janitors"][i]["password"] = params[:newpass]
                File.open("config.json", "w") do |f|
                  f.write(JSON.pretty_generate(settings.config))
                end
                # rerun will detect that this file has changed and restart the server
                File.open("_watch", "w") do |f|
                  f.write(Random.rand.hash.to_s)
                end
                break
              end
            end
            if found == -1 then
              return [400, "Moderator with username " + params[:mod] + " could not be found in config[\"janitors\"]"]
            end
            return [200, "OK"]
          end
          # API routes from here down
          app.get API + "/boards" do
            JSON.dump(config["boards"].select do |key, value| session[:username] or not value["hidden"] end.map do |key, value| key end)
          end
          app.get API + "/board/:board/detail" do |board|
            if config["boards"][board].nil? then
              return [404, "Board not found"]
            end
            if config["boards"][board]["hidden"] and not session[:moderates] then
              return [404, "Board not found"]
            end

            payload = {:name => config["boards"][board]["name"], :desc => config["boards"][board]["desc"], :rules => config["boards"][board]["rules"]}
            return JSON.dump(payload)
          end
          app.get API + "/board/:board" do |board|
            if board == "all" then
              return JSON.dump(get_all(params, session, config))
            end
            return JSON.dump(get_board(board, params, session, config))
          end
          app.get API + "/thread/:id/metadata" do |id|
            if does_thread_exist id then
              id = id.to_i.to_s
              return JSON.dump(make_metadata(make_con(), id, session, config))
            else
              return [404, '{"404": "Thread not found."}']
            end
          end
          app.get API + "/thread/:id/replies" do |id|
            if does_thread_exist id then
              id = id.to_i.to_s
              return JSON.dump(get_thread_replies(id, session, config))
            else
              return [404, '{"404": "Thread not found."}']
            end
          end
        end
      end
    end
  end
end
