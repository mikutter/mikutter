require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../utils')
miquire :core, 'user'
miquire :plugin, 'plugin'
require 'benchmark'

$debug = 2

class TC_User < Test::Unit::TestCase
  def setup
  end
 # !> `*' interpreted as argument prefix

  def test_findbyid
    ids = [135072842, 96340352, 119846900, 164348251, 53645925, 69184777, 86719256, 9796962, 53925634, 34567891, 152338438, 18933027, 146435839, 85958081, 93968713, 59714189, 57326730, 103855657, 97189322, 126657597, 73907675, 80548518, 131326444, 109146393, 123872647, 151549017, 125549889, 28973601, 148586950, 21265656, 91345106, 18667654, 19049499, 73876330, 37897981, 55225427, 14928503, 63865691, 14864316, 17752874, 14976270, 65908912, 99008565, 12454552, 16580912, 117478171, 137301521, 53900587, 20608542, 116352226, 6334552, 106209638, 45302978, 24885728, 105820389, 51016894, 110714354, 18434355, 82888635, 52714058, 4653091, 15579332, 49314273, 15679559, 4801161, 79693644, 99110288, 4268871, 74108688, 96337282, 14138696, 7080152, 84646743, 16331137, 14582398, 63097969, 6024132, 5482822, 73350946, 30605924, 83575449, 30384934, 95126742, 41553246, 43447809, 108839855, 5924642, 96572273, 53622466, 106197987, 19406070, 17642957, 104071204, 82861512, 5523632, 65623624, 18213365, 67428128, 105555582, 14887767, 6151672, 89768361, 42027981, 103012280, 74412179, 14490018, 75435428, 99930747, 43849510, 97244324, 6666552, 79772617, 25488596, 33031948, 98686215, 70858033, 79772335, 6638152, 8484432, 58956473, 96462037, 11453912, 95370444, 54850797, 15149417, 85894406, 62486786, 39950821, 14542307, 64942641, 21636627, 71220962, 79148927, 50669780, 5380012, 78558135, 57149576, 18347418, 5467132, 14980234, 82571791, 5806302, 51739756, 89689962, 45071391, 63760232, 88957701, 43054537, 17777101, 59446033, 19968614, 67595347, 19824807, 14218503, 14178906, 30138120, 17566147, 86558495, 42188053, 86045562, 61767421, 86047608, 86004866, 84663556, 74549009, 82849911, 56077727, 83133015, 75433689, 58363911, 81710787, 82298965, 9478772, 6023392, 33485982, 14568973, 78876224, 79943608, 14598647, 8600682, 77497576, 51813267, 15947185, 27601855, 23046181, 77595030, 65617392, 16110920, 1988111, 74996370, 74083967, 73103514, 75974963, 75747441, 66024141, 4365941, 663273, 57286813, 56925993, 42357998] # !> already initialized constant HYDE
    users = User.findbyid(ids)
    assert_kind_of(Array, users)
    assert_equal("[User(@mnzktw), User(@bot_furby), User(@usagee_jp), User(@mikutter_bot), User(@windymelt), User(@enogu), User(@mkamotsu), User(@sinya8282), User(@tana_ash), User(@rakuta2), User(@realized_001), User(@railgun200), User(@relaxmakoto), User(@quu_s), User(@naka0123456789), User(@ayanohn21), User(@deathfalken), User(@JT_roots), User(@shuhei007), User(@efrumm), User(@peperon999), User(@_hashtagle_), User(@kikutomatu), User(@iorate), User(@wasabiGT), User(@xperia_tan), User(@tototoshi), User(@garincho), User(@seibe3), User(@shibason), User(@highemerly), User(@potpro), User(@fuwacina), User(@fuekuma), User(@touch_lab), User(@the_drunken), User(@katsyoshi), User(@ropross), User(@takkkun), User(@hhc0null), User(@masason), User(@jacknero), User(@athos0220), User(@kura_lab), User(@nisimura2), User(@tomoshitomoshi), User(@tamboo), User(@sweets_portal2), User(@opera_jp), User(@labunix), User(@L4T3X), User(@nsyan), User(@ReturnOfAKIRA), User(@wasabiz), User(@musiloid), User(@aoksh), User(@naota344), User(@fjnli), User(@hitode909), User(@alfaladio), User(@atakig), User(@satoru_h), User(@sakito), User(@kikairoya), User(@hatsune_bot), User(@nari3), User(@windows7_nanami), User(@ton2xia), User(@wyukawa), User(@twj), User(@mi_kami), User(@seibe2), User(@mizuno0to), User(@shuzo_matsuoka), User(@yazuuchi), User(@kabus), User(@peccul), User(@eielh), User(@sanryuu_), User(@rubikitch), User(@nene_loveplus), User(@sirohuku), User(@atsusk), User(@eida82463), User(@kanaya), User(@taoikaihatsu), User(@Hagemashijin), User(@clojurism), User(@myen), User(@ArcCosine), User(@ranking2), User(@sakurako_s), User(@koizuka), User(@zick_minoh), User(@kasuga_t), User(@Phenomer), User(@kirimaru_bot), User(@garaemon), User(@hack_space), User(@inowoo), User(@hirasawa_yui2), User(@gootan_toshia), User(@iPhoneApp_PCF), User(@reot2), User(@r_takaishi), User(@simotsuki), User(@cheshireCats), User(@hatoyamayukio), User(@iR3), User(@reimu), User(@moe335), User(@t_min), User(@kaorin_linux), User(@itm_hataji), User(@dico_leque), User(@luxion), User(@iratqq), User(@dazeko), User(@twfr), User(@hkato193), User(@uho_www), User(@takuma1230), User(@tatezo), User(@Taka_F40), User(@jobhoppers), User(@ooharabucyou), User(@mix3), User(@xxyasyasxx), User(@wuitap), User(@yamapin), User(@woowig), User(@f96q), User(@hi_saito), User(@shinout), User(@Sean_SF), User(@kno2502), User(@takano32), User(@hazumu), User(@cametan_001), User(@random_oracle), User(@inolabo), User(@catharine_san), User(@remtter), User(@atkonn), User(@navel_toshia), User(@uklinux), User(@akira65064), User(@butakao), User(@guruguruatama), User(@takaokouji), User(@atomfe), User(@oshow), User(@TwitBird), User(@osmyism), User(@no_nozaki), User(@nitro_idiot), User(@twittanaka), User(@lynx168), User(@dd_dai_dd), User(@yuzunyan_toshia), User(@test_mogu), User(@BigGerry99), User(@mogu_is_mogu), User(@Yutarine), User(@ginkuri), User(@Satori_fake), User(@hossy001), User(@72pota), User(@myon_toshia), User(@dragonmeteor), User(@valvallow), User(@deg84), User(@ryoyam), User(@twiphoon), User(@mikan_toshia), User(@melsama), User(@Cai0407), User(@OkLife), User(@kimuraya), User(@TweetSmarter), User(@WebUpd8), User(@hoitan), User(@nijibouzu), User(@SHUZO_M), User(@matsudon), User(@hiyokokuma), User(@k_rinko), User(@takane_manaka), User(@soramame_bscl), User(@lime_toshia), User(@cosmobsp), User(@makeplex), User(@rememberthemilk), User(@worldtwittewar), User(@zigavachi), User(@takumin_twi)]", users.inspect)
  end

end # !> method redefined; discarding old miquire
# ~> warning: ./miku/miku.rb:26:in `miku_stream': MIKU::EndofFile
# ~> from ./parser.rb:125:in `_symbol'
# ~> from ./parser.rb:47:in `_parse'
# ~> from ./parser.rb:15:in `parse'
# ~> from ./miku/miku.rb:24:in `miku_stream'
# ~> from ./symboltable.rb:23:in `run_init_script'
# ~> from ./plugin/gui.rb:275
# ~> from ./utils.rb:42:in `require'
# ~> from ./utils.rb:42:in `miquire'
# ~> from ./utils.rb:41:in `each'
# ~> from ./utils.rb:41:in `miquire'
# ~> from ./plugin/plugin.rb:181
# ~> from ./utils.rb:39:in `require'
# ~> from ./utils.rb:39:in `miquire'
# ~> from -:4
# >> Loaded suite -
# >> Started
# >> .
# >> Finished in 0.297701 seconds.
# >> 
# >> 1 tests, 2 assertions, 0 failures, 0 errors
