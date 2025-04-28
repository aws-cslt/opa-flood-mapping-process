import os
import json
import subprocess
import websockets
import time
import requests
import asyncio

job_id = os.environ['JOB_ID']
job_config = os.environ['JOB_CONFIG']
job_parameters = os.environ['JOB_PARAMETERS']
status_socket = os.environ['STATUS_SOCKET']
result_url = os.environ['RESULT_URL']
execution_lang = os.environ['EXECUTION_LANG']

async def runProcess(job_id, job_config, job_parameters, status_socket, result_url, execution_lang, websocket):
    jobProgress = "0"
    try:
        if execution_lang == "fr":
            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"running\",\"progress\":"+ jobProgress +",\"message\":\"Processus démarré.\"}"
        else :
            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"running\",\"progress\":"+ jobProgress +",\"message\":\"Process started.\"}"
        if not websocket is None:
            await websocket.send(status_update)
            print("Update websocket:" + status_update)
        else:
            post_resp = requests.post(url=status_socket, data=status_update)
            print("url: " + status_socket + ", posted: " + status_update)
            print("resp: " + str(post_resp))
        output_format = None
        x_min = None
        x_max = None
        y_min = None
        y_max = None
        sea_level_rise = None
        source_data = None
        stac_api_link = "https://datacube.services.geo.ca/stac/api/search?collections"
        pixel_limit = 1000000
        print("job parameters: " + job_parameters)
        request_json = json.loads(job_parameters)
        print(request_json)
        print("job config: " + job_config)
        config_json = json.loads(job_config)
        print(config_json)
        file_format = None
        include_tide = "true"
        lang = "en"
        if execution_lang == "fr":
            lang = execution_lang
        if "stac_api_link" in config_json:
            stac_api_link = config_json["stac_api_link"]
        if "pixel_limit" in config_json:
            pixel_limit = config_json["pixel_limit"]
        if "inputs" in request_json:
            inputs_json = request_json["inputs"]
            if "bounding_box" in inputs_json:
                bounding_box_json = inputs_json["bounding_box"]
                if "bbox" in bounding_box_json and len(bounding_box_json["bbox"]) == 4:
                    bbox = bounding_box_json["bbox"]
                    x_min = bbox[0]
                    y_min = bbox[1]
                    x_max = bbox[2]
                    y_max = bbox[3]
            if "source_data" in inputs_json:
                source_data = inputs_json["source_data"]
            if "sea_level_rise" in inputs_json:
                sea_level_rise = inputs_json["sea_level_rise"]
            if "include_tide" in inputs_json:
                include_tide = inputs_json["include_tide"]
        if "outputs" in request_json:
            outputs_json = request_json["outputs"]
            if "flood_mapping_nrcan_shapefile" in outputs_json or "flood_mapping_docker_shapefile" in outputs_json:
                output_format = "shape"
                file_format = "application/vnd.shp"
            elif "flood_mapping_nrcan_kml" in outputs_json or "flood_mapping_docker_kml" in outputs_json:
                output_format = "kml"
                file_format = "application/vnd.google-earth.kml+xml"
            elif "flood_mapping_nrcan_tiff" in outputs_json or "flood_mapping_docker_tiff" in outputs_json:
                output_format = "image"
                file_format = "image/tiff"
            elif "flood_mapping_nrcan_geojson" in outputs_json or "flood_mapping_docker_geojson" in outputs_json:
                output_format = "geojson"
                file_format = "application/geo+json"

        if output_format == None or x_min == None or y_min == None or x_max == None or y_max == None or source_data == None or sea_level_rise == None:
            if execution_lang == "fr":
                status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":"+ jobProgress +",\"message\":\"Échec de l'exécution.\"}"
            else:
                status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":"+ jobProgress +",\"message\":\"Failed to run.\"}"
            if not websocket is None:
                await websocket.send(status_update)
                print("Update websocket:" + status_update)
            else:
                post_resp = requests.post(url=status_socket, data=status_update)
                print("url: " + status_socket + ", posted: " + status_update)
                print("resp: " + str(post_resp))
            return
        else :
            process = subprocess.Popen(["Rscript", "/opt/scripts/cslt-query-COG-DataCube.r", job_id, output_format, str(x_min), str(y_min), str(x_max), str(y_max), source_data, str(sea_level_rise), include_tide, lang, stac_api_link, str(pixel_limit)])
            process_running = False
            process_starting = True
            lastRun = False
            status_file_name = "/opt/cubes/" + job_id + "-status"
            while(process_starting):
                if os.path.isfile(status_file_name):
                    process_starting = False
                    process_running = True
                else :
                    if lastRun:
                        if execution_lang == "fr":
                            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":"+ jobProgress +",\"message\":\"Le processus a terminé son exécution mais n'a pas renvoyé de résultat.\"}"
                        else:
                            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":"+ jobProgress +",\"message\":\"Process finished running but didn't return a result.\"}"
                        if not websocket is None:
                            await websocket.send(status_update)
                            print("Update websocket:" + status_update)
                        else:
                            post_resp = requests.post(url=status_socket, data=status_update)
                            print("url: " + status_socket + ", posted: " + status_update)
                            print("resp: " + str(post_resp))
                        return
                    if not process.poll() is None:
                        lastRun = True
                    time.sleep(0.02)
            while(process_running):
                time.sleep(0.02)
                if os.path.isfile("/opt/cubes/" + job_id + "-error"):
                    error_file = open("/opt/cubes/" + job_id + "-error")
                    jobMessage = error_file.readline()
                    if execution_lang == "fr":
                        status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":" + jobProgress + ",\"message\":\"" + jobMessage + "\"}"
                    else:
                        status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":" + jobProgress + ",\"message\":\"" + jobMessage + "\"}"
                    if not websocket is None:
                        await websocket.send(status_update)
                        print("Update websocket:" + status_update)
                    else:
                        post_resp = requests.post(url=status_socket, data=status_update)
                        print("url: " + status_socket + ", posted: " + status_update)
                        print("resp: " + str(post_resp))
                    return
                elif os.path.isfile("/opt/cubes/" + job_id + "-finished.json"):
                    finished_file = open("/opt/cubes/" + job_id + "-finished.json")
                    with finished_file as f:
                            finished_file_data = f.read()
                    print("finished File:" + str(finished_file))
                    finished_json = json.loads(finished_file_data)
                    if "path" in finished_json:
                        print("Path:" + finished_json["path"])
                        file_path = finished_json["path"]
                        file_name = file_path[file_path.rfind("/") +1:]
                        with open(file_path, 'rb') as f2:
                            data = f2.read()
                        print("read file.")
                        resp = requests.put(url=result_url, data=data)
                        if execution_lang == "fr":
                            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"successful\",\"progress\":100,\"message\":\"Le processus est terminé.\",\"filename\":\"" + file_name + "\",\"contentType\":\"" + file_format + "\"}"
                        else:
                            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"successful\",\"progress\":100,\"message\":\"Process has been completed.\",\"filename\":\"" + file_name + "\",\"contentType\":\"" + file_format + "\"}"
                        if not websocket is None:
                            await websocket.send(status_update)
                            print("Update websocket:" + status_update)
                        else:
                            post_resp = requests.post(url=status_socket, data=status_update)
                            print("url: " + status_socket + ", posted: " + status_update)
                            print("resp: " + str(post_resp))
                        return
                else :
                    if lastRun:
                        if execution_lang == "fr":
                            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":" + jobProgress + ",\"message\":\"Le processus a terminé son exécution mais n'a pas renvoyé de résultat.\"}"
                        else:
                            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":" + jobProgress + ",\"message\":\"Process finished running but didn't return a result.\"}"
                        if not websocket is None:
                            await websocket.send(status_update)
                            print("Update websocket:" + status_update)
                        else:
                            post_resp = requests.post(url=status_socket, data=status_update)
                            print("url: " + status_socket + ", posted: " + status_update)
                            print("resp: " + str(post_resp))
                        return
                    if not process.poll() is None:
                        lastRun = True
                    with open(status_file_name, 'r') as f:
                        lines = f.read().splitlines()
                        last_status = lines[-1]
                        if last_status.endswith("%"):
                            new_progress = last_status.split(" ")[-2]
                            if new_progress != jobProgress:
                                jobProgress = new_progress
                                if execution_lang == "fr":
                                    status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"running\",\"progress\":" + jobProgress + ",\"message\":\"Le processus est actuellement en cours d'exécution.\"}"
                                else:
                                    status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"running\",\"progress\":" + jobProgress + ",\"message\":\"Process is currently running.\"}"
                                if not websocket is None:
                                    await websocket.send(status_update)
                                    print("Update websocket:" + status_update)
                                else:
                                    post_resp = requests.post(url=status_socket, data=status_update)
                                    print("url: " + status_socket + ", posted: " + status_update)
                                    print("resp: " + str(post_resp))
    except Exception as e:
        print(e)
        if execution_lang == "fr":
            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":"+ jobProgress +",\"message\":\"Une exception s'est produite lors de l'exécution du processus.\"}"
        else:
            status_update = "{\"action\":\"update\",\"jobId\":\"" + job_id + "\",\"status\":\"failed\",\"progress\":"+ jobProgress +",\"message\":\"An exception occurred when running the process.\"}"
        if not websocket is None:
            await websocket.send(status_update)
            print("Update websocket:" + status_update)
        else:
            post_resp = requests.post(url=status_socket, data=status_update)
            print("url: " + status_socket + ", posted: " + status_update)
            print("resp: " + str(post_resp))
        return
        
async def runProcessCheckWebsockets(job_id, job_config, job_parameters, status_socket, result_url, execution_lang):
    if status_socket.startswith("ws"):
        print("connecting to websocket")
        async with websockets.connect(status_socket) as websocket:
            print("connected")
            await runProcess(job_id, job_config, job_parameters, status_socket, result_url, execution_lang, websocket)
        print("disconnected from websocket")
    else :
        print("no websocket. Using posts instead.")
        await runProcess(job_id, job_config, job_parameters, status_socket, result_url, execution_lang, None)

asyncio.run(runProcessCheckWebsockets(job_id, job_config, job_parameters, status_socket, result_url, execution_lang))