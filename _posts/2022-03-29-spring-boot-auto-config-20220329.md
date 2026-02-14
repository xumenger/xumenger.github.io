---
layout: post
title: Spring Boot 自动化配置原理与演示
categories: spring之IoC spring之AOP
tags: Spring SpringBoot 自动化配置 依赖注入 Java 条件注入 Bean 容器 @SpringBootApplication @EnableConfigurationProperties @ConditionalOnProperty @ConfigurationProperties 
---

## 初始配置如下

pom.xml

```xml
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>1.5.6.RELEASE</version>
        </dependency>
    </dependencies>
```


application.yml 配置如下

```
debug: true

server:
  port: 8880
```

## com.xum.example 包下的内容

Application.java，是SpringBoot 应用的启动入口

```java
package com.xum.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication 
public class Application 
{
    public static void main( String[] args )
    {
        SpringApplication.run(Application.class, args);
    }
}
```

TestController.java 的代码如下，测试其依赖TestLogger

```java
package com.xum.example.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import com.xum.autoconfig.service.TestLogger;


@Controller
@RequestMapping("/path1")
public class TestController 
{
    @Autowired
    TestLogger Logger;
    
    
    @RequestMapping("/path2")
    @ResponseBody
    public String index() 
    {
        Logger.log("info", "test message");
        
        return "ok";
    }
}
```

## com.xum.autoconfig 包下的内容

com.xum.autoconfig 和com.xum.example 分开，是因为@SpringBootApplication 会自动扫描其所属的com.xum.example 下面的@Service、@Component、@Controller 然后注入到Bean 容器中

本次希望测试非启动程序所在包路径下的组件如何进行自动化配置和加载的，所以分开两个！在TestController 中依赖了TestLogger，这两个分属不同的包路径，基于这些条件进行测试

TestAutoConfiguration.java

```java
package com.xum.autoconfig;


import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@ComponentScan("com.xum.autoconfig")
public class TestAutoConfiguration 
{
}
```

TestLogger.java

```java
package com.xum.autoconfig.service;

import javax.annotation.PostConstruct;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Service;

import com.xum.autoconfig.config.TestLogConfig;

@Service
@EnableConfigurationProperties({TestLogConfig.class})
@ConditionalOnProperty(prefix = "logcfg", name = "enabled", havingValue = "true")
public class TestLogger 
{
    @Autowired
    TestLogConfig logConfig;
    
    
    @PostConstruct
    public void init() 
    {
        switch (logConfig.getLogLevel()) {
            case "0":
                System.out.println("debug");
                break;
            case "1":
                System.out.println("info");
                break;
            case "2":
                System.out.println("error");
                break;
            default:
                System.out.println("default");
        }
    }
    
    public void log(String level, String message)
    {
        System.out.println("[level: " + level + "] " + message);
    }
}
```

TestLogConfig.java

```java
package com.xum.autoconfig.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.properties.ConfigurationProperties;


@ConfigurationProperties("logcfg")
public class TestLogConfig 
{
    public final static String ON = "on";
    public final static String OFF = "off";
    public final static String FALSE = "false";
    
    
    @Value("${logcfg.log-level}")
    private String logLevel;         // 日志级别配置，比如      0-debug；1-info；2-warn；3-error；4-fatal
    
    // 默认值为 on
    @Value("${logcfg.on-off:on}")
    private String onOff = ON;       // 默认开启
    
    
    public String getLogLevel() {
        return logLevel;
    }
    public void setLogLevel(String logLevel) {
        this.logLevel = logLevel;
    }
    public String getOnOff() {
        return onOff;
    }
    public void setOnOff(String onOff) {
        this.onOff = onOff;
    }
    
    
    /**
     * 是否开启开关
     * @return
     */
    public boolean isOff()
    {
        return OFF.equals(this.onOff) || FALSE.equals(this.onOff);
    }
    
}
```

## 启动程序验证

基于以上的配置和开发，启动后发现如下报错

```
***************************
APPLICATION FAILED TO START
***************************

Description:

Field Logger in com.xum.example.controller.TestController required a bean of type 'com.xum.autoconfig.service.TestLogger' that could not be found.


Action:

Consider defining a bean of type 'com.xum.autoconfig.service.TestLogger' in your configuration.
```

出现这个报错的话是两个原因

1. com.xum.autoconfig.service.TestLogger 不在@SpringBootApplication 的com.xum.example 包下面，所以不会因为@SpringBootApplication 被扫描注入
2. 因为TestLogger 上面加了注解`@ConditionalOnProperty(prefix = "logcfg", name = "enabled", havingValue = "true")`，而application.yml 中没有相应的配置，所以也不会被注入


首先在src/main/resources/META-INF/spring.factories 中增加内容如下

```
org.springframework.boot.autoconfigure.EnableAutoConfiguration=com.xum.autoconfig.TestAutoConfiguration
```

另外在application.yml 中增加配置

```
logcfg:
  enabled: true
  log-level: 0
```

然后即可启动成功，TestLogger 注入到Bean 容器中

以上两个设置缺一不可，而两个配置的原因不同

第一个spring.factories 就会加载com.xum.autoconfig.TestAutoConfiguration 配置，而com.xum.autoconfig.TestAutoConfiguration 代码如下，重点是`@ComponentScan("com.xum.autoconfig")`，指定去扫描com.xum.autoconfig 包下的组件

```java
package com.xum.autoconfig;


import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@ComponentScan("com.xum.autoconfig")        // ===> 指定扫描com.xum.autoconfig 中的Bean
public class TestAutoConfiguration 
{
}
```

就算是有上面的设置也不行，因为TestLogger 有注解`@ConditionalOnProperty(prefix = "logcfg", name = "enabled", havingValue = "true")`，这就是SpringBoot 的条件注入，只有在application.yml 中有对应的配置才行

```java
package com.xum.autoconfig.service;

import javax.annotation.PostConstruct;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Service;

import com.xum.autoconfig.config.TestLogConfig;

@Service
@EnableConfigurationProperties({TestLogConfig.class})
@ConditionalOnProperty(prefix = "logcfg", name = "enabled", havingValue = "true")
public class TestLogger 
{
    @Autowired
    TestLogConfig logConfig;
    
    ...

}
```

以上也是开发SpringBoot SDK 的时候需要关注的语法特性！！

## 再补充一个可能导致Bean 重复注入的问题

TestLogger 上有注解`@EnableConfigurationProperties({TestLogConfig.class})`

这样就会在注入TestLogger 的时候，顺便将TestLogConfig 作为Bean 注入到容器中，TestLogConfig 也就不需要@Component 之类的注解

如果再加了@Component 注解的话，就会在启动的时候报错！

```
***************************
APPLICATION FAILED TO START
***************************

Description:

Field logConfig in com.xum.autoconfig.service.TestLogger required a single bean, but 2 were found:
    - testLogConfig: defined in file [C:\Users\80263584\ScalaIDE\SpringExample\target\classes\com\xum\autoconfig\config\TestLogConfig.class]
    - logcfg-com.xum.autoconfig.config.TestLogConfig: defined in null


Action:

Consider marking one of the beans as @Primary, updating the consumer to accept multiple beans, or using @Qualifier to identify the bean that should be consumed
```

TestLogConfig 注入两次，启动的时候报错！！
