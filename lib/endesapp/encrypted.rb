module Encrypted
  def generate_salt
    BCrypt::Engine.generate_salt
  end

  def encrypt_password(str)
    salt     = generate_salt
    result   = {enc_password: BCrypt::Engine.hash_secret(str, salt), salt: salt}
  end

  def generate_secure_string
    "#{SecureRandom.hex(15)}#{SecureRandom.base64}"
  end

  def genereate_secure_random(length)
    random_txt = SecureRandom.hex(length.to_i)

    check      = AUser.where(uniq_folder_name: random_txt)

    while check.length > 1
      random_txt = SecureRandom.hex(length.to_i)
      check      = AUser.where(uniq_folder_name: random_txt)
    end

    return random_txt
  end

  def authenticate_user(opts = {})
    a_user      = AUser.where(username: opts[:username]).take

    unless a_user.blank?
      if a_user.encrypted_password.eql? BCrypt::Engine.hash_secret(opts[:password], a_user.password)
        a_user
      end
    end
  end

  def encryption_process(opts = {})
    is_keep_file      = opts[:is_keep_file]
    is_custom_key     = opts[:is_custom_key]
    file              = opts[:file]
    algorithms        = opts[:algo_type]
    folder_name       = ac_current_user.uniq_folder_name

    cipher            = OpenSSL::Cipher::Cipher.new(algorithms)
    cipher.encrypt

    if is_custom_key
      key             = opts[:custom_key]
      iv              = opts[:custom_iv]
    else
      # key             = cipher.random_key
      # iv              = cipher.random_iv
      key             = SecureRandom.base64(24)
      iv              = SecureRandom.base64(20)
    end

    enc_string_key    = encrypt_password(key)
    enc_string_iv     = encrypt_password(iv)

    hashed_key        = enc_string_key[:salt]
    hashed_iv         = enc_string_iv[:salt]

    encrypted_key     = enc_string_key[:enc_password]
    encrypted_iv      = enc_string_iv[:enc_password]

    hashed_keys       = {
      :hashed_key   => hashed_key,
      :hashed_iv    => hashed_iv
    }

    encrypted_keys    = {
      :encrypted_key => encrypted_key,
      :encrypted_iv  => encrypted_iv
    }

    cipher.key        = key
    cipher.iv         = iv
    dir_path          = "#{Rails.root.join('users', folder_name, 'temp')}"
    real_file_path    = File.join(dir_path,file.original_filename)

    ac_write_file(file, dir_path)

    files             = File.open(real_file_path)
    # secret_text       = Base64.encode64(files.read)
    secret_text       = files.read
    
    # cipher_text       = cipher.update(Base64.decode64(secret_text))
    cipher_text       = cipher.update(secret_text)

    begin
      cipher_text       << cipher.final
      status          = "success"
      message         = "OK"
    rescue Exception => e
      status          = "danger"
      message         = e.message
    end

    ac_remove_file(dir_path)

    file_name       = "encrypted_#{file.original_filename}"
    
    # if is_keep_file
      dir_path        = "#{Rails.root.join('users', folder_name, 'encrypted')}"
      file_path       = "#{File.join(dir_path, file_name)}"

      unless Dir.exists?(dir_path)
        FileUtils.mkdir_p(dir_path)
      end

      File.open(file_path, "wb") {|f| f.write(cipher_text)}
      # write_file      = File.new(file_path, "w")
      
      # write_file.write(Base64.encode64(cipher_text))
      # write_file.close
    # end

    result            = {
      :hashed_keys    => hashed_keys.to_json,
      :encrypted_keys => encrypted_keys.to_json,
      :is_custom_key  => is_custom_key,
      :is_keep_file   => is_keep_file,
      :file_name      => file.original_filename,
      :file_path      => file_path,
      :key            => key,
      :iv             => iv,
      :file_name      => file_name,
      :is_keep_file   => is_keep_file,
      :status         => status,
      :message        => message
    }
  end
end