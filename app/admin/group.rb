# frozen_string_literal: true

ActiveAdmin.register Group do
  menu parent: 'グループ'
  csv_importable
  active_admin_action_log
  permit_params { Group.column_names }
  actions :all, except: [:destroy]

  index do
    id_column
    column :name
    column :email
    column :description
    column :deleted_at
    actions do |group|
      br
      link_to '割当を編集', edit_group_assign_admin_group_path(group)
    end
  end

  show do
    attributes_table do
      row :id
      row :name
      row :email
      row :description
      row 'メンバー' do |group|
        group.users.each do |user|
          div { user.name }
        end
      end
      row :deleted_at
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :email
      f.input :description
      f.input :deleted_at, as: :datepicker
    end
    f.actions
  end

  action_item :group_assign, only: %i[show edit] do
    link_to 'グループ割当を編集する', edit_group_assign_admin_group_path(group)
  end

  member_action :edit_group_assign, method: :get do
    @group = resource
  end

  member_action :update_group_assign, method: :post do
    @group = resource
    users_before = @group.users.map(&:name)

    @group.users = User.where(id: params[:user_ids])

    if @group.save
      users_after = @group.users.map(&:name)

      ActiveAdminActionLog.create do |log|
        log.user = current_user
        log.resource = resource
        log.path = resource_path
        log.action = action_name
        log.changes_log = { 'users' => [users_before, users_after] }
      end

      redirect_to action: :show
    else
      flash[:error] = @group.errors.full_messages
      redirect_back(fallback_location: admin_root_path)
    end
  end
end
