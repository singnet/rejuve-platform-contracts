
async function getSignForIdentity(identityOwnerAddress, tokenURI, nonce, contractAddress, identityOwner) 
{
    const message = ethers.utils.solidityKeccak256(
        ['address','string', 'uint256' ,'address'],
        [
          identityOwnerAddress,
          tokenURI,
          nonce,
          contractAddress
        ],
      )

    const arrayifyMessage = ethers.utils.arrayify(message)
    const flatSignature = await identityOwner.signMessage(arrayifyMessage)

    return flatSignature;
}

module.exports.getSignForIdentity = getSignForIdentity;