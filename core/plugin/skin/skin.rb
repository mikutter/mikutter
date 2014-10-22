# -*- coding: utf-8 -*-

Plugin.create :skin do
  # スキンのリストを返す
  def get_skin_list()
    dirs = Dir.glob(File.join(Skin::SKIN_ROOT, "**", "*.png")).map { |_| File.dirname(_) }.uniq
    dirs.map { |_| _.gsub(/^#{Skin::SKIN_ROOT}\//, "") }
  end

  # 設定
  settings("スキン") do
    dirs = get_skin_list.inject({:vanilla => _("（デフォルト）")}) { |hash, _|
      hash[_] = _
      hash
    }

    select(_("スキンディレクトリ（再起動後に反映）"), :skin_dir, dirs)
  end
end
