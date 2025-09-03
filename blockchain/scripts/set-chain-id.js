const hre = require('hardhat');
async function main() {
    try {
        // Set chain ID to 5777 (0x1691 in hex)
        await hre.network.provider.send('hardhat_setChainId', ['0x1691']);
        console.log('Chain ID set to 5777 successfully');
    } catch (error) {
        console.error('Error setting chain ID:', error);
        process.exit(1);
    }
}
main().catch(error => {
    console.error(error);
    process.exit(1);
});
