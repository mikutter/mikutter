# -*- coding: utf-8 -*-
# 毎時間ファイルキャッシュを監視して削除する

Plugin.create(:api_request_file_cache) do

  def gc
    notice "apirequest cache was deleted. "+MikuTwitter::Cache.garbage_collect.inspect
    Reserver.new(3600){
      gc }
  end

  Reserver.new(3600){ gc }

end
