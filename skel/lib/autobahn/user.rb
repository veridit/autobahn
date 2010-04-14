module Autobahn
  module User
    module ClassMethods
      def authenticate(email, password)
        user = find_by_email(email)
        if user and user.authenticate(password)
          user
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.validates_format_of :epost, :with => /^([^@ ]+)@((?:[-a-z0-9æøå]+\.)+[a-z]{2,})$/i, :allow_nil => true
    end

    def to_label
      name
    end

    def password=(password)
      if password
        self.password_salt ||= ActiveSupport::SecureRandom.hex(32)
        self.password_digest = digest(password)
      else
        self.password_salt = nil
        self.password_digest = nil
      end

      @password = password
    end

    def password
      @password
    end

    def authenticate(password)
      digest(password) == password_digest
    end

    private

    def digest(password)
      Digest::SHA1.hexdigest("#{password_salt}#{password}")
    end
  end
end
