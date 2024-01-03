add timer to calculate the install time of flow rules

flow_create_test2
  based on flow_create_test1
  add function:
    1.add timer to calculate the install time of flow rules

flow_create_nic_bf3
  based on flow_create_test2
  add function:
    1.create flow rules faking ovs generation rules
    2.do not quit until send command
  **!! not function now, rules is right, but packet can not be forward as the testpmd run
  **!! problem may relate to the port init