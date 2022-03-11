const { spawn } = require("child_process");

const run = () => {
  console.log("start local dev chain...");
  try {
    // 1337表示启动测试网络的id
    // 也可以直接用命令行启动一个
    spawn("ganache-cli -d --db data -i 1337 --port 8545", {
      shell: true,
      stdio: "inherit",
    });
  } catch (e) {
    console.log(e);
  }
};
run();
