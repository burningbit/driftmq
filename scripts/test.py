import sys
import paho.mqtt.client as mqtt
import logging
logging.basicConfig(level=logging.DEBUG)

# If you want to use a specific client id, use
# mqttc = mqtt.Client("client-id")
# but note that the client id must be unique on the broker. Leaving the client
# id parameter empty will generate a random id for you.



def on_connect(mqttc, obj, flags, rc):
    print("Hey hey")
    print("rc: "+str(rc))

def on_message(mqttc, obj, msg):
    print(msg.topic+" "+str(msg.qos)+" "+str(msg.payload))

def on_publish(mqttc, obj, mid):
    print("mid: "+str(mid))

def on_subscribe(mqttc, obj, mid, granted_qos):
    print("Subscribed: "+str(mid)+" "+str(granted_qos))

def on_log(mqttc, obj, level, string):
    print(string)

mqttc = mqtt.Client(transport="websockets")   
logger = logging.getLogger(__name__)
mqttc.enable_logger(logger)

mqttc.ws_set_options(path="/ws/mqtt")
mqttc.on_message = on_message
mqttc.on_connect = on_connect
mqttc.on_publish = on_publish
mqttc.on_subscribe = on_subscribe
mqttc.connect("localhost", 4000, 60)
mqttc.subscribe("test/iot", 0)

mqttc.loop_forever()