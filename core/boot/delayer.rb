# -*- coding: utf-8 -*-

miquire :lib, "delayer"

Delayer.default = Delayer.generate_class(priority: [:ui_response,
                                                    :routine_active,
                                                    :ui_passive,
                                                    :routine_passive],
                                         default: :routine_passive,
                                         expire: 0.02)

