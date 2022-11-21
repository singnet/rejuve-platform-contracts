// Create a wallet to sign the message with
let privateKey = '0x0123456789012345678901234567890123456789012345678901234567890123';
let wallet = new ethers.Wallet(privateKey);
console.log("Wallet : ", wallet.address);

let message = "Hello World";
//signMsg();


//---------------------------------

async function signMsg() {
    // Sign the string message
let flatSig = await wallet.signMessage(message);
console.log("signature : ", flatSig);
}

