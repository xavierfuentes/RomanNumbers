<?php

namespace Xavifuefer\TestBundle\Tests\Controller;

use Xavifuefer\TestBundle\Controller\DefaultController;

class DefaultControllerTest extends \PHPUnit_Framework_TestCase
{
    public function testIndex()
    {
        $controller = new DefaultController;

        $units = $controller->toRoman(7);
        $this->AssertEquals("VII", $units);

        $tens = $controller->toRoman(14);
        $this->AssertEquals("XIV", $tens);

        $hundreds = $controller->toRoman(152);
        $this->AssertEquals("CLII", $hundreds);

        $thousands = $controller->toRoman(1982);
        $this->AssertEquals("MCMLXXXII", $thousands);

        $units = $controller->toNumber("V");
        $this->AssertEquals("5", $units);

        $tens = $controller->toNumber("XIII");
        $this->AssertEquals("13", $tens);

        $hundreds = $controller->toNumber("DCLXVI");
        $this->AssertEquals("666", $hundreds);

        $thousands = $controller->toNumber("MCMLXXXII");
        $this->AssertEquals("1982", $thousands);
    }
}
