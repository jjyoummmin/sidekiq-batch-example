# frozen_string_literal: true

class CreateBillJob
  include Sidekiq::Worker

  sidekiq_options queue: :create_bill
  sidekiq_options :retry => 3

  def perform(user_id, month)
    user = User.find(user_id)
    return if user.bills.where(month: month).any? 
    user.bills.create!(month:  month, amount: rand(10000..100000), description: Faker::Hobby.activity)
  end

  private

  def self.send_start_message(month, total_count)
    start_msg = "#{month} 정산서 발행을 시작합니다. 발행 유저 수 : *#{total_count}*"
    Rails.logger.info "===슬랙 시작 메세지 보내기==="
    Rails.logger.info start_msg
  end

  def self.send_end_message(month, total_count, failed_arguments=nil)
    success_count = total_count.to_i - ( failed_arguments&.size || 0 )

    end_msg = "#{month} 정산서 발행이 종료되었습니다. 성공 개수: *#{success_count}*"

    if failed_arguments.present?
      failed_arguments = failed_arguments.sort_by {|x| x['args'][1]}
      end_msg += "\n\n실패한 유저ID\n"
      end_msg = failed_arguments.reduce(msg) {|msg, x| msg + "\n*#{x['args'][1]}* : #{x['err']}"}
    end

    Rails.logger.info "===슬랙 종료 메세지 보내기==="
    Rails.logger.info end_msg
  end
end