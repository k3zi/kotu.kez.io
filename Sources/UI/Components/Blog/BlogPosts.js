import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Pagination from './../react-bootstrap-pagination';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';

import CreatePostModal from './Modals/CreatePostModal';
import DeletePostModal from './Modals/DeletePostModal';

import Helpers from './../Helpers';
import UserContext from './../Context/User';

class BlogPosts extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showDeletePostModal: null,
            showCreatePostModal: false,
            posts: [],
            metadata: {
                page: 1,
                per: 15,
                total: 0
            }
        };
    }

    componentDidMount() {
        this.load();
    }

    async load() {
        const response = await fetch(`/api/blog?page=${this.state.metadata.page}&per=${this.state.metadata.per}`);
        if (response.ok) {
            const result = await response.json();

            this.setState({
                posts: result.items,
                metadata: result.metadata
            });
        }
    }

    async showDeletePostModal(note) {
        this.setState({
            showDeletePostModal: note
        });
        await this.load();
    }

    async showCreatePostModal(show) {
        this.setState({
            showCreatePostModal: show
        });
        await this.load();
    }

    loadPage(page) {
        const metadata = this.state.metadata;
        metadata.page = page;
        this.load();
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <div>
                    <h2>Articles {user && user.permissions.includes('blog') && <Button className='float-end' variant="primary" onClick={() => this.showCreatePostModal(true)}>Create Article</Button>}</h2>
                    <hr />
                    {this.state.posts.map((post, i) => {
                        return (<div key={i}>
                            {i !== 0 && <hr />}
                            <h3 className='mb-0'>
                                <LinkContainer style={{cursor:'pointer'}} exact to={`/article/${post.id}`}>
                                    <span>{post.title}</span>
                                </LinkContainer>
                            </h3>
                            <div className='d-flex align-items-center mb-2 text-muted'>
                                <span><strong>Author:</strong> {post.owner.username}</span>
                                &nbsp;&nbsp;|
                                <span className='ps-2'><strong>Created:</strong> {new Intl.DateTimeFormat([], { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).format(new Date(post.createdAt))}</span>
                                {post.isDraft && <span className='text-info ps-2'>(Draft)</span>}
                                {user && user.permissions.includes('blog') && <LinkContainer style={{cursor:'pointer'}} exact to={`/article/edit/${post.id}`}>
                                    <span className='text-primary ps-2'>Edit <i class="bi bi-pencil-square"></i></span>
                                </LinkContainer>}
                                {user && user.permissions.includes('blog') && <span style={{cursor:'pointer'}} onClick={() => this.showDeletePostModal(post)} className='text-danger ps-2'>Delete <i class="bi bi-trash"></i></span>}
                            </div>

                            <div className='read-more' dangerouslySetInnerHTML={{__html: Helpers.parseMarkdown(post.content ? post.content : '(No Content)')}}></div>
                        </div>);
                    })}
                    <hr />
                    <Pagination totalPages={Math.ceil(this.state.metadata.total / this.state.metadata.per)} currentPage={this.state.metadata.page} showMax={7} onClick={(i) => this.loadPage(i)} />
                    <CreatePostModal show={this.state.showCreatePostModal} onSuccess={() => this.showCreatePostModal(false)} onHide={() => this.showCreatePostModal(false)} />
                    <DeletePostModal post={this.state.showDeletePostModal} didDelete={() => this.showDeletePostModal(null)} didCancel={() => this.showDeletePostModal(null)} onHide={() => this.showDeletePostModal(null)} />
                </div>
            )
        }</UserContext.Consumer>);
    }
}

export default BlogPosts;
