
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

async function getSignForData(dataOwnerAddress, dataHash, nonce, contractAddress, dataOwner) 
{
  const message = ethers.utils.solidityKeccak256(
    ['address','bytes', 'uint256' ,'address'],
      [
        dataOwnerAddress,
        dataHash,
        nonce,
        contractAddress
      ],
  )

  const arrayifyMessage = ethers.utils.arrayify(message)
  const flatSignature = await dataOwner.signMessage(arrayifyMessage)

  return flatSignature;
}

async function getSignForPermission(dataOwnerAddress, requesterID, dataHash, nextProductUID, nonce, expiration, contractAddress, dataOwner) 
{
  const message = ethers.utils.solidityKeccak256(
    ['address', 'uint256', 'bytes', 'uint256', 'uint256', 'uint256' ,'address'],
      [
        dataOwnerAddress,
        requesterID,
        dataHash,
        nextProductUID,
        nonce,
        expiration,
        contractAddress
      ],
  )

  const arrayifyMessage = ethers.utils.arrayify(message)
  const flatSignature = await dataOwner.signMessage(arrayifyMessage)

  return flatSignature;
}



module.exports.getSignForIdentity = getSignForIdentity;
module.exports.getSignForData = getSignForData;
module.exports.getSignForPermission = getSignForPermission;
