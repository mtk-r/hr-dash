# frozen_string_literal: true

describe MonthlyReportsController, type: :request do
  let!(:report) { create(:shipped_monthly_report, :with_comments) }
  let(:user) { create(:user) }
  before { login user }

  describe '#index GET /monthly_reports' do
    before { get monthly_reports_path }
    it { expect(response).to have_http_status :success }
    it { expect(response).to render_template('monthly_reports/index') }
    it { expect(response.body).to match report.user.name }
  end

  describe '#user GET /monthly_reports/users/:user_id' do
    context 'view my_reports' do
      before { get user_monthly_reports_path(user) }
      it { expect(response).to have_http_status :success }
      it { expect(response).to render_template('monthly_reports/user') }
      it { expect(response.body).to match user.name }
    end

    context 'view other_users_reports' do
      let(:other_user) { create(:user) }
      before { get user_monthly_reports_path(other_user) }
      it { expect(response).to have_http_status :success }
      it { expect(response).to render_template('monthly_reports/user') }
      it { expect(response.body).to match other_user.name }
    end
  end

  describe '#show GET /monthly_reports/:id' do
    context 'my report registered as shipped' do
      let(:report) { create(:shipped_monthly_report, user: user) }
      before { get monthly_report_path(report) }
      it { expect(response).to have_http_status :ok }
      it { expect(response).to render_template('monthly_reports/show') }
      it { expect(response.body).to match report.user.name }
    end

    context 'my report registered as wip' do
      let(:report) { create(:monthly_report, :wip, user: user) }
      before { get monthly_report_path(report) }
      it { expect(response).to have_http_status :ok }
      it { expect(response).to render_template('monthly_reports/show') }
      it { expect(response.body).to match report.user.name }
    end

    context 'report registered as shipped by other user' do
      let(:other_report) { create(:shipped_monthly_report) }
      before { get monthly_report_path(other_report) }
      it { expect(response).to have_http_status :ok }
      it { expect(response).to render_template 'monthly_reports/show' }
      it { expect(response.body).to match other_report.user.name }
    end

    context 'report registered as wip by other user' do
      let(:other_report) { create(:monthly_report, :wip) }
      before { get monthly_report_path(other_report) }
      it { expect(response).to have_http_status :forbidden }
      it { expect(response).to render_template 'errors/403' }
    end
  end

  describe '#new GET /monthly_reports/new' do
    context 'If monthly report on the last month is not registered' do
      before { get new_monthly_report_path }
      it { expect(response).to have_http_status :success }
      it { expect(response).to render_template('monthly_reports/new') }
      it { expect(response.body).not_to match '先月の月報をコピー' }
    end

    context 'If monthly report on the last month has been registered' do
      let!(:prev_monthly_report) { create(:monthly_report_tag).monthly_report }
      let(:params) { { target_month: prev_monthly_report.target_month.next_month } }
      before do
        login prev_monthly_report.user
        get new_monthly_report_path params
      end

      it { expect(response).to have_http_status :success }
      it { expect(response).to render_template('monthly_reports/new') }
      it { expect(response.body).to match '先月の月報をコピー' }
    end

    context 'when not the end of the month of 5 days.' do
      before do
        Timecop.freeze(Date.new(2016, 5, 26))
        get new_monthly_report_path
      end

      after { Timecop.return }
      it { expect(response.body).not_to match Time.now.strftime('%Y年%m月') }
    end

    context 'when the end of the month of 5 days.' do
      before do
        Timecop.freeze(Date.new(2016, 5, 27))
        get new_monthly_report_path
      end

      after { Timecop.return }
      it { expect(response.body).to match Time.now.strftime('%Y年%m月') }
    end
  end

  describe '#create POST /monthly_reports' do
    let(:report_params) { attributes_for(:monthly_report) }
    let(:process_params) do
      build(:monthly_working_process).processes.select { |_, v| v }.map { |k, _| k }
    end
    let(:tag_params) { 'Ruby,Rails' }
    let(:user_report) { MonthlyReport.find_by(user: user) }

    context 'valid' do
      before { post monthly_reports_path, params: post_params }
      context 'registered as wip' do
        let(:post_params) { { monthly_report: report_params, wip: true } }
        it { expect(response).to have_http_status :redirect }
        it { expect(user_report.present?).to eq true }
      end

      context 'registered as shipped' do
        let(:post_params) do
          {
            monthly_report: report_params.merge(monthly_report_tags: tag_params),
            working_process: process_params,
          }
        end

        it { expect(response).to have_http_status :redirect }
        it { expect(user_report.present?).to eq true }
      end
    end

    context 'invalid' do
      let(:post_params) { { monthly_report: report_params.except('target_month') } }
      before { post monthly_reports_path, params: post_params }
      it { expect(response).to have_http_status :success }
      it { expect(response).to render_template('monthly_reports/new') }
      it { expect(user_report.present?).to eq false }
    end

    describe 'notify mail' do
      after(:each) { ActionMailer::Base.deliveries.clear }
      context 'registered as shipped' do
        let(:post_params) do
          {
            monthly_report: report_params.merge(monthly_report_tags: tag_params),
            working_process: process_params,
          }
        end
        subject { post monthly_reports_path, params: post_params }
        it { expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1) }
      end

      context 'registered as wip' do
        let(:post_params) { { monthly_report: report_params, wip: true } }
        before { post monthly_reports_path, params: post_params }
        it { expect(ActionMailer::Base.deliveries.size).to eq(0) }
      end
    end

    describe '#working_process' do
      let(:tag_params) { 'Ruby,Rails' }
      let(:post_params) do
        {
          monthly_report: report_params.merge(monthly_report_tags: tag_params),
          working_process: [process_params],
          wip: true,
        }
      end
      before { post monthly_reports_path, params: post_params }
      subject { user_report.monthly_working_process }

      context 'valid' do
        let(:processes) { build(:monthly_working_process).processes }
        let(:process_params) do
          processes.select { |_, v| v }.map { |k, _| k }
        end
        it { expect(response).to have_http_status :redirect }
        it { expect(subject.processes).to eq processes }
      end

      context 'invalid' do
        let(:process_params) { 'invalid_process' }
        it { expect(response).to have_http_status :redirect }
        it { expect(subject.processes.values).not_to be_a(MonthlyWorkingProcess) }
      end
    end
  end

  describe '#edit GET /monthly_reports/:id/edit' do
    context 'invalid' do
      before { get edit_monthly_report_path(report) }
      it { expect(response).to have_http_status :not_found }
    end

    context 'valid' do
      before do
        login report.user
        get edit_monthly_report_path(report, target_month: report.target_month)
      end

      it { expect(response).to have_http_status :success }
      it { expect(response).to render_template('monthly_reports/edit') }
      it { expect(response.body).to match report.target_month.strftime('%Y年%m月') }
      it { expect(response.body).not_to match '先月の月報をコピー' }
    end
  end

  describe '#copy GET /monthly_reports/copy' do
    context 'invalid' do
      context 'not_found' do
        let(:params) { { target_month: Date.today.beginning_of_month } }
        before { get copy_monthly_reports_path params }
        it { expect(response).to have_http_status :not_found }
      end
    end

    context 'valid' do
      context 'If monthly report on the last month has been registered' do
        let!(:prev_monthly_report) { create(:shipped_monthly_report) }
        let(:params) { { target_month: prev_monthly_report.target_month.next_month.beginning_of_month } }
        before do
          login prev_monthly_report.user
          get copy_monthly_reports_path params
        end

        it { expect(response).to have_http_status :success }
        it { expect(response).to render_template('monthly_reports/new') }
        it { expect(response.body).not_to match '先月の月報をコピー' }
        # 何かしらの担当工程がactiveになってるかどうかをチェック
        it { expect(response.body).to match 'label class=\"btn btn-default active\"' }
        it { expect(response.body).to match prev_monthly_report.business_content }
        it { expect(response.body).to match prev_monthly_report.looking_back }
        it { expect(response.body).to match prev_monthly_report.project_summary }
        it { expect(response.body).to match prev_monthly_report.next_month_goals }
        it { expect(response.body).to match prev_monthly_report.tags.first.name }
      end
    end
  end

  describe '#update PATCH /monthly_report/:id' do
    let(:report_params) { attributes_for(:monthly_report, :shipped) }
    let(:tag_params) { 'Ruby,Rails' }
    let(:process_params) do
      build(:monthly_working_process).processes.select { |_, v| v }.map { |k, _| k }
    end
    let(:find_params) { report_params.reject { |k, _| k == :shipped_at } }
    let(:user_report) { MonthlyReport.find_by(find_params, user: report.user) }
    let(:patch_params) do
      {
        monthly_report: report_params.merge(monthly_report_tags: tag_params),
        working_process: process_params,
      }
    end

    context 'valid' do
      before do
        login report.user
      end
      context 'when shipped' do
        before do
          patch monthly_report_path report, patch_params
        end

        it { expect(response).to have_http_status :redirect }
        it { expect(user_report).to be_present }
      end

      describe 'notify mail' do
        after(:each) do
          ActionMailer::Base.deliveries.clear
        end

        context 'when was shipped' do
          subject { patch monthly_report_path report, patch_params }
          it { expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0) }
        end

        context 'when shipped' do
          let!(:wip_report) { create(:monthly_report, :wip) }
          before do
            login wip_report.user
          end
          subject { patch monthly_report_path wip_report, patch_params }
          it { expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1) }
        end

        context 'when wipped' do
          let(:patch_params) do
            {
              monthly_report: report_params.merge(monthly_report_tags: tag_params),
              working_process: process_params,
              wip: true,
            }
          end
          before { patch monthly_report_path report, patch_params }
          it { expect(ActionMailer::Base.deliveries.size).to eq(0) }
        end
      end
    end

    context 'not_found' do
      before { patch monthly_report_path report, patch_params }
      it { expect(response).to have_http_status :not_found }
      it { expect(user_report).to be_nil }
    end
  end
end
