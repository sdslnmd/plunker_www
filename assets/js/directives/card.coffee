#= require ./../../vendor/ui-bootstrap/ui-bootstrap-tpls-0.3.0
#= require ./../../vendor/jquery.lazyload/jquery.lazyload

#= require ./../services/quickview
#= require ./../services/url
#= require ./../services/notifier

#= require ./../directives/inlineuser
#= require ./../directives/inlineplunk
#= require ./../directives/taglist

#= require ./../../vendor/jquery-timeago/jquery.timeago

module = angular.module "plunker.card", [
  "plunker.inlineuser"
  "plunker.inlineplunk"
  "plunker.quickview"
  "plunker.plunkinfo"
  "plunker.taglist"
  "plunker.url"
  "ui.bootstrap"
]

module.directive "plunkerCard", [ "$timeout", "$compile", "quickview", "visitor", "url", "notifier", ($timeout, $compile, quickview, visitor, url, notifier) ->
  restrict: "EAC"
  scope:
    plunk: "="
  template: """
    <div class="plunk" ng-show="plunk.id" ng-class="{starred: plunk.thumbed, owned: plunk.token}">
      <div class="card">
        <ul class="operations">
          <li><a class="btn" title="Edit this Plunk" ng-href="/edit/{{plunk.id}}"><i class="icon-edit"></i></a></li>
          <li><a class="btn" title="View this Plunk in an overlay" ng-click="showQuickView(plunk, $event)"><i class="icon-play"></i></a></li>
          <li><a class="btn" title="View the detailed information about this Plunk" ng-href="/{{plunk.id}}"><i class="icon-info-sign"></i></a></li>
          <li><a class="btn" title="Open the embedded view of this Plunk" ng-href="{{url.embed}}/{{plunk.id}}/" target="_blank"><i class="icon-external-link"></i></a></li>
          <li ng-show="plunk.isWritable()"><a class="btn btn-danger" title="Delete this plunk" ng-click="confirmDelete(plunk)"><i class="icon-trash"></i></a></li>
          <li ng-show="visitor.logged_in && plunk.thumbed"><button title="Unstar this Plunk" class="btn starred" ng-click="plunk.star()"><i class="icon-star"></i></button></li>
          <li ng-show="visitor.logged_in && !plunk.thumbed"><button title="Star this Plunk" class="btn" ng-click="plunk.star()"><i class="icon-star"></i></button></li>
        </ul>
        <h4 title="{{plunk.description}}">{{plunk.description}}</h4>
        <img src="http://placehold.it/248x186&text=Loading..." data-original="http://immediatenet.com/t/l3?Size=1024x768&URL={{plunk.raw_url}}?_={{plunk.updated_at | date:'yyyy-MM-ddTHH:mm:ssZ'}}" />
        <plunker-taglist tags="plunk.tags"></plunker-taglist>
        <plunker-plunk-info plunk="plunk"></plunker-plunk-info>
        <ul class="meta">
          <li ng-show="plunk.fork_of" tooltip-placement="bottom" tooltip="This plunk was forked from another">
            <plunker-inline-plunk plunk="plunk.parent"><i class="icon-share-alt"></i></plunker-inline-plunk>
          </li>
          <li ng-show="plunk.files['README.md']" tooltip-placement="bottom" tooltip="Full description of Plunk">
            <a ng-href="{{plunk.id}}#README"><i class="icon-info"></i></a>
          </li>
          <li ng-show="plunk.thumbed" tooltip-placement="bottom" tooltip="You starred this Plunk">
            <a ng-href="/users/{{visitor.user.login}}/favorites"><i class="icon-pushpin"></i></a>
          </li>
          <li ng-show="plunk.private" tooltip-placement="bottom" tooltip="Private plunk - only you see this plunk listed here">
            <a ng-href="{{plunk.id}}"><i class="icon-eye-close"></i></a>
          </li>
        </ul>
      </div>
      <div class="about">
        <plunker-inline-user user="plunk.user"></plunker-inline-user>
        <abbr class="timeago updated_at" title="{{plunk.updated_at}}" ng-bind="plunk.updated_at | date:'medium'"></abbr>
      </div>
    </div>
  """
  link: ($scope, $el, attrs) ->
    $scope.visitor = visitor
    $scope.url = url
    
    $scope.$watch "plunk.updated_at", ->
      $timeout -> $("abbr.timeago", $el).timeago()
    
    $("img", $el).lazyload(event: "urlready")
    
    $scope.$watch "plunk.raw_url", -> 
      $timeout -> $("img", $el).trigger("urlready")
    
    $scope.confirmDelete = (plunk) ->
      notifier.confirm "Are you sure you would like to delete this plunk?",
        confirm: -> plunk.destroy()
      
    $scope.showQuickView = (plunk, $event) ->
      quickview.show(plunk)
      
      $event.preventDefault()
      $event.stopPropagation()

    $scope.toggleStar = (plunk, $event) ->
      #quickview.show(plunk)
      
      $event.preventDefault()
      $event.stopPropagation()

]