"""Pin and import SRD 2014 reference data, without enabling unimplemented abilities."""
from pathlib import Path
import concurrent.futures,hashlib,json,urllib.request
ROOT=Path(__file__).resolve().parents[1]
COMMIT="a6212beb4b278917c2cff41c2b04c4ef4f3e0d6f"
REPO="5e-bits/5e-database"
OUT=ROOT/"rules/content/srd2014"
def get(url):
    request=urllib.request.Request(url,headers={"User-Agent":"Tibia5e-content-import"})
    return urllib.request.urlopen(request,timeout=45).read()
def main():
    tree=json.loads(get(f"https://api.github.com/repos/{REPO}/git/trees/{COMMIT}?recursive=1"))["tree"]
    prefix="src/2014/en/"
    files=[entry["path"] for entry in tree if entry["path"].startswith(prefix) and entry["path"].endswith(".json") and entry["path"].count("/")==3]
    if not files:raise ValueError("Pinned source has no SRD 2014 data")
    OUT.mkdir(parents=True,exist_ok=True)
    def save(path):
        raw=get(f"https://raw.githubusercontent.com/{REPO}/{COMMIT}/{path}")
        values=json.loads(raw)
        if not isinstance(values,list):raise ValueError("Expected collection: "+path)
        indexes=[v["index"] for v in values]
        if len(indexes)!=len(set(indexes)):raise ValueError("Duplicate content index in "+path)
        dest=OUT/Path(path).name;dest.write_bytes(raw)
        return {"file":dest.name,"count":len(values),"sha256":hashlib.sha256(raw).hexdigest()}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool: entries=list(pool.map(save,files))
    licenses=[e["path"] for e in tree if "/" not in e["path"] and ("license" in e["path"].lower() or "ogl" in e["path"].lower())]
    for name in licenses:(OUT/name).write_bytes(get(f"https://raw.githubusercontent.com/{REPO}/{COMMIT}/{name}"))
    manifest={"edition":"2014","rules_reference":"SRD 5.1","source_repository":f"https://github.com/{REPO}","commit":COMMIT,"collections":sorted(entries,key=lambda e:e["file"]),"activation":"Reference data only. Combat handlers and player choices require implementation and validation before enabling content."}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2))
    print(json.dumps({e["file"]:e["count"] for e in entries},indent=2))
if __name__=="__main__":main()
