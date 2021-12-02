variable "cluster_name" {
  default = "eks-nginx"
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add toadd to the aws-auth configmap."
  type        = list(string)
  default = [ "11111111111", "22222222222" ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type        = list(object({
      rolearn  = string
      username = string
      groups   = list(string)
  }))

  default = [ {
    groups = [ "system:masters" ]
    rolearn = "arn:aws:iam::11111111111:role/role1"
    username = "role1"
  } ]
}

variable "map_users" {
    description = "Additional IAM users to add to the aws-auth configmap."
    type = list(object({
        userarn  = string
        username = string
        groups   = list(string)
    }))
  default = [ {
    groups = [ "system:masters" ]
    userarn = "arn:aws:iam:22222222222:user/user1"
    username = "user1"
  },
  {
    groups = [ "system:masters" ]
    userarn = "arn:aws:iam:22222222222:user/user2"
    username = "user2"
  } ]
}