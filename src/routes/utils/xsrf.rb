XsrfToken = Struct.new(:token, :type, :board, :parent, :expiry, :text)
XsrfTTL = 60 * 60
class Xsrf
  def self.gensym
    Base64.encode64(Random.new.bytes(24)).strip
  end

  def self.reply(board, parent)
    if !Config.get["captcha"]
      return false
    end
    sym = gensym
    text = make_text
    token = XsrfToken.new(sym, :reply, board, parent, Time.new.to_i + XsrfTTL, text[0])
    Awoo.xsrf[sym] = token
    [token, text[1]]
  end

  def self.board(board)
    if !Config.get["captcha"]
      return false
    end
    sym = gensym
    text = make_text
    token = XsrfToken.new(sym, :reply, board, 0, Time.new.to_i + XsrfTTL, text[0])
    Awoo.xsrf[sym] = token
    [token, text[1]]
  end

  def self._validate(board, parent, token, text)
    token = Awoo.xsrf[token]
    if token.nil? || token.expiry < Time.new.to_i
      return false
    end
    if token[:type] == :board && token[:board] == "all"
      return text == token.text
    end
    if token[:type] == :board && token[:board] == board
      return text == token.text
    end
    if token[:type] == :reply && token[:parent] == parent
      return text == token.text
    end
    return false
  end
  
  def self.validate(board, parent, token, text)
    if !Config.get["captcha"]
      return true
    end
    result = _validate(board, parent, token, text)
    if result
      Awoo.xsrf.delete token
    end
    return result
  end
end
