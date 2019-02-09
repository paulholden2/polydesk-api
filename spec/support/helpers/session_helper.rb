module SessionHelper
  def set_request_headers(resp)
    { 'ACCEPT' => "application/json",
      'Content-Type' => "application/json",
      'access-token' => resp['access-token'],
      'token-type' => resp['token-type'],
      'client' => resp['client'],
      'expiry' => resp['expiry'],
      'uid' => resp['uid'] }
  end

  def account_login(identifier, email, password)
    host! 'localhost'
    post '/auth/sign_in', params: { email: email, password: password }
    return set_request_headers(response.headers)
  end
end