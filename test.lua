require "sensors.gpio"

while true do
    v = gpioget(1,72)
    print ("Val:"..v)
    gpioset(1,71,v)
    os.execute("sleep 1")
--    gpioset(1,71,0)
end
