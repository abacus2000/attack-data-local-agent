
# About the project

This project is intended for generally exploring how LLM Agents can integrate with Graph data, using ATT&CK data as an example. 

By providing the LLM with tools (see the ./tools dir) that handle the graph queries, and designing each of the queries effectively to provide available steps to the next node, navigating a Graph database with an LLM is intuative. 

Please see the notebook I drafted which demonstraits the walk through the ATT&CK data Graph 
* https://github.com/abacus2000/attack-data-local-agent/blob/main/attack_agent.ipynb

I further broke down all of the Strands Basics concepts in a sparate project here; if you are not familiar with Strands Agents, going through those notebooks will let you test agents locally:
* https://github.com/abacus2000/strands_agents_study


# Frugal Testing 

Additionally, for the sake of proving the system quickly in its current state the Strands Agent Agent() object uses the default Bedrock agent on-demand endpoints which require localy AWS account redentials. 

For true locallity with open weight modles, please see this notebook in my other project with and example of Ollama use generally; the changes required are only an Ollama import and the calling of that Ollama Agent (or whichever LLM runtime you choose for locallity). 
* https://github.com/abacus2000/strands_agents_study/blob/main/Concepts/Agents/AgentLoop/1_basic_agent_loop_and_simple_tool_usage.ipynb

The list of Model Providers we can use in Strands and assocaited runtimes can be found here:
* https://strandsagents.com/docs/user-guide/concepts/model-providers/

# Gettings started with attack-data-local-agent: General Tips (if you are new to this kind of thing) 

GIT clone the project. 

Start with:

```bash
docker compose up -d
```

An init script is defined which imports the data. 
Here's how it works:

  - The init service shares the same neo4j_data volume as the neo4j service
  - It waits for Neo4j to be healthy via depends_on: condition: service_healthy
  - On first run: no .attack-data-initialized marker exists, so it runs the import, then writes the marker to /data/
  - On subsequent runs: sees the marker, prints a skip message, exits immediately

If we run docker compose down -v it deletes the volume (and the marker in the volumn), so the next up re-imports, making the script properly idempotent.

To check if the init script has loaded the data successfully, naviate to http://localhost:7474 in your browser. 
Run `MATCH (n:STIXObject) RETURN count(n) AS total_nodes;`
If you get 4,724, the node import succeeded.   

You can check the logs of the startup script with `docker compose -f attack-data-agent/docker-compose.yml logs -f neo4j`

Stop with 

```bash
docker compose down
```

Stop and remove volumns with 
```bash 
docker compose down -v
```

Check you memory and adjust with `df -h .` in your project directory. 
The example below shows Avail with 23 Gibibyes which is ~24 GBs. 
```bash
 % df -h .
Filesystem      Size    Used   Avail Capacity iused ifree %iused  Mounted on
/dev/disk3s1   228Gi   165Gi    23Gi    88%    2.0M  237M    1%   /System/Volumes/Data
```

check the healthcheck logs running the below in the project directory [1]:
```bash 
docker inspect attack-neo4j --format='{{json .State.Health}}' | jq
```
e.g. 
```bash
 % docker inspect attack-neo4j --format='{{json .State.Health}}' | jq

{
  "Status": "healthy",
  "FailingStreak": 0,
  "Log": [...]
  ...
}
```


== References ==

[1] https://jqlang.org/

[2] https://github.com/neo4j/apoc

[3] https://stackoverflow.com/questions/79332692/setting-the-apoc-import-file-enabled-true-in-the-neo4j-conf

[4] https://community.neo4j.com/t/how-to-batch-json-records-using-apoc-library-for-better-importing/45928/2
