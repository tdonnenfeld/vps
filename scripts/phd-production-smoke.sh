#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/phd-hub
cd "$APP_DIR"
container="$(docker compose --env-file .env -f infrastructure/compose.yml -f infrastructure/compose.override.yml ps -q phd-web)"
if [[ -z "$container" ]]; then
  echo "::error::phd-web container not running"
  exit 1
fi

# The script runs only inside the already authenticated VPS SSH session.
# Remote-User is sent to the container loopback, never through public Traefik.
docker exec -i "$container" node - <<'NODE'
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");

const base = "http://127.0.0.1:3000";
const username = process.env.ALLOWED_USER;
assert(username, "ALLOWED_USER is not configured");
const title = "Automated VPS smoke " + randomUUID();
const today = new Intl.DateTimeFormat("en-CA",{timeZone:"Europe/Madrid",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
let entryId = null;
let mainError = null;

async function request(path, options={}) {
  const { method="GET", body, ...rest } = options;
  const response = await fetch(base+path,{
    method,
    headers: {"Remote-User": username, ...(body!==undefined?{"Content-Type":"application/json"}:{})},
    body: body!==undefined?JSON.stringify(body):undefined,
    signal: AbortSignal.timeout(12000),
    ...rest
  });
  const text = await response.text();
  let result;
  try { result=JSON.parse(text); } catch { result={}; }
  if(!response.ok) throw Error(path+": HTTP "+response.status+" "+JSON.stringify(result).slice(0,240));
  return result;
}

async function run() {
  const entries=await request("/api/journal?month="+today.slice(0,7));
  assert(Array.isArray(entries),"Journal must return an array");
  console.log("PASS: authenticated production journal GET");

  try {
    const created=await request("/api/journal",{method:"POST",body:{date:today,title,content:"Temporary deployment smoke check; safe to delete.",period:"DAY"}});
    entryId=created.id;
    assert(entryId,"Missing created journal entry ID");
    let month=await request("/api/journal?month="+today.slice(0,7));
    assert(month.some(x=>x.id===entryId),"Created entry missing after database read");
    console.log("PASS: production journal create + persisted read");

    const updated=await request("/api/journal/"+encodeURIComponent(entryId),{method:"PATCH",body:{date:today,title,content:"Updated by production smoke test.",period:"WEEK"}});
    assert.equal(updated.period,"WEEK");
    console.log("PASS: production journal edit");

    const commitSha="a".repeat(40);
    const link=await request("/api/journal/"+encodeURIComponent(entryId)+"/links",{method:"POST",body:{
      source:"github",externalId:commitSha,label:"Temporary test commit",url:"https://github.com/tdonnenfeld/web-phd/commit/"+commitSha
    }});
    assert(link.id,"Resource link not created");
    month=await request("/api/journal?month="+today.slice(0,7));
    assert(month.find(x=>x.id===entryId)?.links?.some(x=>x.externalId===commitSha),"Resource link not persisted");
    console.log("PASS: production journal-to-commit linking");

    const tasks=await request("/api/vikunja");
    assert.equal(tasks.configured,true,"Vikunja token not configured");
    assert(Array.isArray(tasks.tasks),"Vikunja task read failed");
    console.log("PASS: real Vikunja connectivity and authorized read");

    const experiments=await request("/api/experiments");
    assert.equal(experiments.configured,true,"MLflow URL not configured");
    assert(Array.isArray(experiments.runs),"MLflow run read failed");
    console.log("PASS: real MLflow connectivity and run read");

    const activity=await request("/api/activity?month="+today.slice(0,7));
    assert(Array.isArray(activity),"Combined activity API did not respond");
    console.log("PASS: combined activity endpoint");
  } catch(e){mainError=e;}
  finally {
    if(entryId) {
      try {
        await request("/api/journal/"+encodeURIComponent(entryId),{method:"DELETE"});
        const remaining=await request("/api/journal?month="+today.slice(0,7));
        assert(!remaining.some(x=>x.id===entryId),"Temporary entry not deleted");
        console.log("PASS: production test record and linked resources deleted");
      } catch(cleanupError){
        console.error("CLEANUP FAILURE for entry "+entryId+": "+String(cleanupError));
        process.exitCode=1;
      }
    }
  }
  if(mainError)throw mainError;
}
run().catch(e=>{console.error("FAIL: "+String(e));process.exitCode=1;});
NODE
