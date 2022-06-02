# isucon_terraform

aws-isucon  
https://github.com/matsuu/aws-isucon

ISUCON公式AMIを使ってAWS上にISUCON環境をTerraformで構築オレオレレシピ  
https://qiita.com/momotaro98/items/24cec11fc050c014057f

terraformでkey pairを作成してEC2にアクセス  
https://qiita.com/instant_baby/items/7a70d644c54efa273179

TARGET_EC2=i-059522a6d0db55441


```
aws ssm start-session --target $TARGET_EC2 --region ap-northeast-1 --profile $AWS_PROFILE
```

https://selmertsx.hatenablog.com/entry/2021/08/11/AWS%E3%81%AB%E3%81%8A%E3%81%91%E3%82%8B%E8%B8%8F%E3%81%BF%E5%8F%B0%28Bastion%29%E3%82%B5%E3%83%BC%E3%83%90%E3%83%BC%E3%81%AE%E4%BD%9C%E3%82%8A%E6%96%B9


```
Host isucon-bastion
  HostName ${EC2 internal IP}.ap-northeast-1.compute.internal
  User ubuntu
  Port 22
  ProxyCommand aws ssm start-session --target ${EC2 ID} --document-name AWS-StartSSHSession --region ap-northeast-1 --parameters "portNumber=22" --profile ${aws profile}
  IdentityFile ~/.ssh/${bastionのkey pair}
```
