// This action helps us find the correct download for
// the broker and demo staging deploys.

const core = require("@actions/core");

const octokit = require("@actions/github").getOctokit(core.getInput("token"));

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const get = (obj, ...path) => {
  let res = obj;
  for (const el of path) {
    if (res) res = res[el];
    else break;
  }
  return res;
};

async function run() {
  const owner = core.getInput("owner");
  const repo = core.getInput("repo");
  let didWarn = false;

  for (let attempts = 0; attempts < 60; attempts++) {
    let data;
    try {
      data = await octokit.graphql(
        `
        query currentWorkflowRun($owner: String!, $repo: String!) {
          repository(owner: $owner, name: $repo) {
            defaultBranchRef { target { ... on Commit {
              tarballUrl
              checkSuites(first: 10) { nodes {
                app { name }
                conclusion
                workflowRun {
                  databaseId
                }
              } }
            } } }
          }
        }
        `,
        { owner, repo }
      );
    } catch (err) {
      if (!didWarn) {
        didWarn = true;
        core.warning(`Using partial GraphQL response because of errors`);
        console.error(err.errors);
      }
      data = err.data;
    }

    const head = get(data, "repository", "defaultBranchRef", "target");
    if (!head) {
      throw Error("Could not get default branch info");
    }

    const checkSuites = (get(head, "checkSuites", "nodes") || []).filter(
      (suite) => get(suite, "app", "name") === "GitHub Actions"
    );

    // Success condition.
    if (
      checkSuites.length > 0 &&
      checkSuites.every((suite) => suite.conclusion === "SUCCESS")
    ) {
      return setOutputs(head, checkSuites);
    }

    if (
      checkSuites.some(
        (suite) => suite.conclusion !== null && suite.conclusion !== "SUCCESS"
      )
    ) {
      throw Error("portier-broker checks unsuccessful");
    }

    if (attempts < 60) {
      core.info("Waiting for portier-broker checks to complete");
      await delay(15000);
    }
  }

  throw Error("Timed out waiting for portier-broker checks");
}

async function setOutputs(head, checkSuites) {
  core.info(`Tarball URL: ${head.tarballUrl}`);
  core.setOutput("tarball_url", head.tarballUrl);

  const artifactName = core.getInput("artifact");
  if (artifactName) {
    let artifactUrl;
    for (const checkSuite of checkSuites) {
      const res = await octokit.rest.actions.listWorkflowRunArtifacts({
        owner: core.getInput("owner"),
        repo: core.getInput("repo"),
        run_id: checkSuite.workflowRun.databaseId,
      });
      const artifact = res.data.artifacts.find(
        (artifact) => artifact.name === artifactName
      );
      if (artifact) {
        artifactUrl = artifact.archive_download_url;
        break;
      }
    }
    if (!artifactUrl) {
      throw Error("Could not find Linux debug build");
    }
    core.info(`Artifact URL: ${artifactUrl}`);
    core.setOutput("artifact_url", artifactUrl);
  }
}

run().catch((err) => {
  core.setFailed(err.message);
});
