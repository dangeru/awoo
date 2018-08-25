XsrfToken = Struct.new(:token, :type, :board, :parent, :expiry)
XsrfTTL = 60 * 60
class Xsrf
  def self.gensym
    Base64.encode64(Random.new.bytes(24)).strip
  end

  def self.reply(board, parent)
    token = gensym
    Awoo.xsrf[token] = XsrfToken.new(token, :reply, board, parent, Time.new.to_i + XsrfTTL)
  end

  def self.board(board)
    token = gensym
    Awoo.xsrf[token] = XsrfToken.new(token, :reply, board, 0, Time.new.to_i + XsrfTTL)
  end

  def self._validate(board, parent, token)
    token = Awoo.xsrf[token]
    if token.nil? || token.expiry < Time.new.to_i
      return false
    end
    if token[:type] == :board && token[:board] == "all"
      return true
    end
    if token[:type] == :board && token[:board] == board
      return true
    end
    if token[:type] == :reply && token[:parent] == parent
      return true
    end
    return false
  end
  
  def self.validate(board, parent, token)
    result = _validate(board, parent, token)
    if result
      Awoo.xsrf.delete token
    end
    return result
  end
end
