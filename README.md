Sidekiq-batch Example
---------------------

### 설치해야 하는 gem
```
gem 'sidekiq'
gem 'sidekiq-batch'
```

### 이 파일을 위주로 보세요
```
```

### 직접 실행 해보려면 
1. git clone
2. bundle install
3. mysql.server start / redis-server
4. rails db:create / rails db:migrate / rails db:seed
5. bundle exec sidekiq
6. rails c 에서 서비스 호출해 보세영~
```
CreateBillService.new('2022-08').create
```