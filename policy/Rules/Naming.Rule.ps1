Rule 'Azure.AppService.Name.Convention' -Type 'Microsoft.Web/sites' {
  $Assert.Match($PSItem.name, '^[a-z0-9-]{3,60}$')
}
