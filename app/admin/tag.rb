ActiveAdmin.register Tag do
  csv_importable validate: false
  active_admin_action_log
  permit_params { Tag.column_names }
  actions :all, except: [:destroy]

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :name
      f.input :status, as: :select, collection: Tag.statuses.keys
    end
    f.actions
  end
end
