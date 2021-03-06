module Validations
  class FreshRecordValidator < ActiveModel::Validator
    def validate(new_record)
      latest = TwitterUser.latest_by(uid: new_record.uid)
      return if latest.nil?

      if latest.fresh?
        new_record.errors[:base] << "[#{latest.id}] is recently updated."
      end
    end
  end
end
