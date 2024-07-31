// architecture of CAM_RTL




+-------------------------+
|                         |
|       Processor         |
|                         |
+-----------+-------------+
            |
            | APB Interface
            |
+-----------v-------------+
| CAM_Config_TLP Module   |
|                         |
|  +-------------------+  |
|  |    APB Interface  |  |
|  |                   |  |
|  |  +-------------+  |  |
|  |  |  pclk       |  |  |
|  |  |  presetn    |  |  |
|  |  |  psel       |  |  |
|  |  |  paddr      |  |  |
|  |  |  penable    |  |  |
|  |  |  pwrite     |  |  |
|  |  |  pwdata     |  |  |
|  |  |  prdata     |  |  |
|  |  |  pready     |  |  |
|  |  +-------------+  |  |
|  +---------|---------+  |
|            |            |
|            v            |
|  +-------------------+  |
|  |  Register Block   |  |
|  |  (CF8 and CFC)    |  |
|  |                   |  |
|  |  +-------------+  |  |
|  |  |  cf8_reg    |  |  |
|  |  |  cfc_reg    |  |  |
|  |  +-------------+  |  |
|  +---------|---------+  |
|            |            |
|            v            |
|  +-------------------+  |
|  |  FSM Logic        |  |
|  |  (Idle, Capture   |  |
|  |   write/read,   |  |
|  |   Wait for        |  |
|  |   Completion)     |  |
|  +-------------------+  |
|            |            |
|            v            |
|  +-------------------+  |
|  |  Config TLP       |  |
|  |  Generation       |  |
|  |  (Header and      |  |
|  |  Data)            |  |
|  +-------------------+  |
|            |            |
|            v            |
|  +-------------------+  |
|  |  Config TLP       |  |
|  |  Interface        |  |
|  |                   |  |
|  |  +-------------+  |  |
|  |  |  o_cfg_tlp  |  |  |
|  |  |  o_cfg_tlp_valid| |
|  |  |  i_cfg_tlp_ready| |
|  |  +-------------+  |  |
|  +---------|---------+  |
|            |            |
|            v            |
|  +-------------------+  |
|  |  Completion TLP   |  |
|  |  Interface        |  |
|  |                   |  |
|  |  +-------------+  |  |
|  |  |  i_cmpl_tlp  |  |  |
|  |  |  i_cmpl_valid|  |  |
|  |  |  o_cmpl_ready|  |  |
|  |  +-------------+  |  |
|  +-------------------+  |
|                         |
+-------------------------+

