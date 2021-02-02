--
-- 74LS74
--


library ieee;
use ieee.std_logic_1164.all;


ENTITY ls74 IS
PORT(d,
	  clr,
     pre,
     clk   : IN std_logic;
     q     : OUT std_logic);
END ls74;

ARCHITECTURE behav OF ls74 IS
BEGIN
   PROCESS(clk, clr, pre)
   BEGIN
      IF clr = '0' THEN
         q <= '0' AFTER 25 ns;
      ELSIF pre = '0' THEN
         q <= '1' AFTER 13 ns;
      ELSIF clk'EVENT AND clk = '1' THEN
         IF d = '1' THEN
            q <= '1' AFTER 13 ns;
         ELSE
            q <= '0' AFTER 25 ns;
         END IF;
      END IF;
   END PROCESS;
END behav;
