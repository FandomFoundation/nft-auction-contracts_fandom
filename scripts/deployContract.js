const { spawn } = require("child_process");

const run = async () => {
  console.log("📄 Deploying and updating contracts...");
  try {
    spawn("truffle migrate --reset --compile-all --network ropsten", {
      shell: true,
      stdio: "inherit",
    });
  } catch (e) {
    console.log(e);
  }
};
run();
