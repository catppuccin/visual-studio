# took the plain list of colors from https://github.com/catppuccin/catppuccin
# on 05-26-2023
$latte = "00000000", "dc8a78", "dd7878", "ea76cb", "8839ef", "d20f39", "e64553", "fe640b", "df8e1d", "40a02b", "179299", "04a5e5", "209fb5", "1e66f5", "7287fd", "4c4f69", "5c5f77", "6c6f85", "7c7f93", "8c8fa1", "9ca0b0", "acb0be", "bcc0cc", "ccd0da","eff1f5", "e6e9ef", "dce0e8"
$frappe = "00000000", "f2d5cf", "eebebe", "f4b8e4", "ca9ee6", "e78284", "ea999c", "ef9f76", "e5c890", "a6d189", "81c8be", "99d1db", "85c1dc", "8caaee", "babbf1", "c6d0f5", "b5bfe2", "a5adce", "949cbb", "838ba7", "737994", "626880", "51576d", "414559", "303446", "292c3c", "232634"
$macchiato = "00000000", "f4dbd6", "f0c6c6", "f5bde6", "c6a0f6", "ed8796", "ee99a0", "f5a97f", "eed49f", "a6da95", "8bd5ca", "91d7e3", "7dc4e4", "8aadf4", "b7bdf8", "cad3f5", "b8c0e0", "a5adcb", "939ab7", "8087a2", "6e738d", "5b6078", "494d64", "363a4f", "24273a", "1e2030", "181926"
$mocha = "00000000", "f5e0dc", "f2cdcd", "f5c2e7", "cba6f7", "f38ba8", "eba0ac", "fab387", "f9e2af", "a6e3a1", "94e2d5", "89dceb", "74c7ec", "89b4fa", "b4befe", "cdd6f4", "bac2de", "a6adc8", "9399b2", "7f849c", "6c7086", "585b70", "45475a", "313244", "1e1e2e", "181825", "11111b"

function GetColors
{
  param ( $name )

  switch ($name)
  {
    "latte"
    { $result = $latte
    }
    "frappe"
    { $result = $frappe
    }
    "macchiato"
    { $result = $macchiato
    }
    "mocha"
    { $result = $mocha
    }
  }

  return $result
}

function GetThemePath
{
  param ( $name )

  switch ($name)
  {
    "latte"
    { $result = "/Catppuccin Latte.vstheme"
    }
    "frappe"
    { $result = "/Catppuccin Frappé.vstheme"
    }
    "macchiato"
    { $result = "/Catppuccin Macchiato.vstheme"
    }
    "mocha"
    { $result = "/Catppuccin Mocha.vstheme"
    }
  }

  $location = Get-Location
  return "$location$result"
}

$sourceColors = GetColors $args[0]
$targetColors = GetColors $args[1]
$sourcePath = GetThemePath $args[0]
$targetPath = GetThemePath $args[1]

Write-Host $sourcePath

$sourceXml = New-Object -TypeName XML
$sourceXml.Load($sourcePath)
$targetXml = New-Object -TypeName XML
$targetXml.Load($targetPath)

# this loop is a bit messy but it gets its job done
# it looks up every color on the source theme which matches a known catppuccin color
# it then searches the node in the target theme and replaces the color or creates the node if it not existing
for (($i = 0); $i -lt $sourceColors.Length; $i++)
{
  $sourceColor = $sourceColors[$i].ToUpper()
  $items = Select-Xml -Xml $sourceXml -XPath "//*[contains(@Source, `"$sourceColor`")]"
  $count = $item.Length
  Write-Host "found $count items for $sourceColor"
  foreach ($item in $items)
  {
    $targetColor = $targetColors[$i].ToUpper()
    $categoryNode = $item.Node.ParentNode.ParentNode
    $categoryName = $categoryNode.Name
    $categoryGuid = $categoryNode.GUID

    $targetCategory = Select-Xml -Xml $targetXml -XPath "//Category[@Name=`"$categoryName`" and @GUID=`"$categoryGuid`"]"
    if ($targetCategory -eq $null)
    {
      Write-Host "adding group $categoryName"
      $newNode = $targetXml.CreateElement("Category")
      $newNode.SetAttribute("Name", $categoryName)
      $newNode.SetAttribute("GUID", $categoryGuid)
      $themeNode = Select-Xml -Xml $targetXml -XPath "//Theme"
      $themeNode.Node.AppendChild($newNode)
      $targetCategory = Select-Xml -Xml $targetXml -XPath "//Category[@Name=`"$categoryName`"]"
    }

    $colorName = $item.Node.ParentNode.Name
    $targetColorNode = Select-Xml -Xml $targetCategory.Node -XPath "Color[@Name=`"$colorName`"]"
    if ($targetColorNode -eq $null)
    {
      Write-Host "adding color node"
      $newNode = $targetXml.CreateElement("Color")
      $newNode.SetAttribute("Name", $colorName)
      $targetCategory.Node.AppendChild($newNode)
      $targetColorNode = Select-Xml -Xml $targetCategory.Node -XPath "Color[@Name=`"$colorName`"]"
    }

    $nodeType = $item.Node.Name
    $targetNodeToModify = Select-Xml -Xml $targetColorNode.Node -XPath "$nodeType"
    $targetOpacity = $item.Node.GetAttribute("Source").Substring(0, 2)
    $targetTypeAttributeValue = $item.Node.GetAttribute("Type")
    if ($targetNodeToModify -eq $null)
    {
      Write-Host "adding $nodeType node"
      $newNode = $targetXml.CreateElement("$nodeType")
      $targetColorNode.Node.AppendChild($newNode)
      $targetNodeToModify = Select-Xml -Xml $targetColorNode.Node -XPath "$nodeType"
    }

    if ($targetColor.Length -eq 6)
    {
      $targetColor = "$targetOpacity$targetColor"
    }

    $targetNodeToModify.Node.SetAttribute("Type", $targetTypeAttributeValue)
    $targetColorAttribute = $targetNodeToModify.Node.SetAttribute("Source", "$targetColor")

    $sortedNodes = $targetColorNode.Node.ChildNodes | Sort-Object Name
    if ($sortedNodes.Count -gt 1)
    {
      foreach ($sortedChild in $sortedNodes)
      {
        $targetColorNode.Node.RemoveChild($sortedChild)
        $targetColorNode.Node.AppendChild($sortedChild)
      }
    }

    Write-Host "$colorName.$nodeType = $targetColor"
  }
}

$targetXml.Save($targetPath)
