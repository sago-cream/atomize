import type { JSX } from 'react';
import { Bot, Gauge, GraduationCap } from 'lucide-react';

import { websiteText } from '../../app-state';
import { SiteFooter, SiteHeader } from './SiteFrame';

const featureIcons = [GraduationCap, Gauge, Bot] as const;

export function LandingPage(): JSX.Element {
    const copy = websiteText.landing;

    return (
        <main className='site-page'>
            <div className='site-shell'>
                <SiteHeader />
                <section className='landing-hero'>
                    <div className='landing-hero__copy'>
                        <p className='site-eyebrow'>{copy.eyebrow}</p>
                        <h1>{copy.title}</h1>
                        <p className='landing-hero__lede'>{copy.description}</p>
                        <div className='landing-actions'>
                            <a
                                className='site-button site-button--primary'
                                href='/app'
                            >
                                {copy.primaryAction}
                            </a>
                            <a
                                className='site-button site-button--secondary'
                                href='#features'
                            >
                                {copy.secondaryAction}
                            </a>
                        </div>
                    </div>
                    <div
                        aria-label={copy.demoLabel}
                        className='factor-demo'
                        role='img'
                    >
                        <div className='factor-demo__target'>
                            {copy.demoTarget}
                        </div>
                        <div aria-hidden='true' className='factor-demo__beam' />
                        <div className='factor-demo__factors'>
                            {copy.demoFactors.map((factor, index) => (
                                <span key={`${factor}-${index}`}>{factor}</span>
                            ))}
                        </div>
                        <p>{copy.demoEquation}</p>
                    </div>
                </section>

                <section
                    aria-labelledby='features-title'
                    className='feature-section'
                    id='features'
                >
                    <div className='section-heading'>
                        <p className='site-eyebrow'>{websiteText.brand}</p>
                        <h2 id='features-title'>{copy.featuresTitle}</h2>
                    </div>
                    <div className='feature-grid'>
                        {copy.features.map((feature, index) => {
                            const Icon = featureIcons[index];

                            return (
                                <article
                                    className='feature-card'
                                    key={feature.title}
                                >
                                    <span className='feature-card__icon'>
                                        <Icon aria-hidden='true' />
                                    </span>
                                    <h3>{feature.title}</h3>
                                    <p>{feature.body}</p>
                                </article>
                            );
                        })}
                    </div>
                </section>

                <section className='landing-final'>
                    <div>
                        <h2>{copy.finalTitle}</h2>
                        <p>{copy.finalBody}</p>
                    </div>
                    <a className='site-button site-button--inverse' href='/app'>
                        {copy.finalAction}
                    </a>
                </section>
                <SiteFooter />
            </div>
        </main>
    );
}
