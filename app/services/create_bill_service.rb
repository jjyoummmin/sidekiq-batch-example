class CreateBillService

  def initialize(month)
    @month = month
  end

  # 모든 유저의 정산서 발행 job을 등록합니다.
  def create
    batch_job = BatchJob.new('CreateBillJob', @month, 'create_bill')
    batch_job.push_jobs(User, 1000) do |users|
      users.map { |user| [user.id, @month] }
    end
  end

end