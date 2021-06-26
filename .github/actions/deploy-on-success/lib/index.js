// This action is simple enough that we could've done it with curl, but it is
// here because we need to order it after the Cachix action 'post' step.

const core = require("@actions/core");

const octokit = require("@actions/github").getOctokit(core.getInput("token"));

async function run() {
  if (!core.getState("isPost")) {
    core.saveState("isPost", true);
    return;
  }

  const [owner, repo] = process.env.GITHUB_REPOSITORY.split("/");
  const ref = process.env.GITHUB_SHA;
  const storePath = process.env.DEPLOY_STORE_PATH;
  if (!storePath) {
    throw Error("DEPLOY_STORE_PATH not set");
  }

  octokit.rest.repos.createDeployment({
    owner,
    repo,
    ref,
    payload: { store_path: storePath },
    required_contexts: [],
  });
}

run().catch((err) => {
  core.setFailed(err.message);
});
