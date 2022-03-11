async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying contracts with the account:', deployer.address);

  console.log('Account balance:', (await deployer.getBalance()).toString());

  const RichApeCarClubNFT = await ethers.getContractFactory(
    'RichApeCarClubNFT'
  );
  const raccNFT = await RichApeCarClubNFT.deploy(5, '');

  await raccNFT.deployed();

  console.log('RichApeCarClubNFT address:', raccNFT.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
